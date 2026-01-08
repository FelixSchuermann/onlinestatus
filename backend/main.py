import os
import json
import random
from datetime import datetime, timedelta
from typing import List, Optional, Dict

import uvicorn
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field

# --- Config ---
origins = ["*"]

# API Token for authentication (set via environment variable or use default for dev)
# In production, set this via: export API_TOKEN="your-secure-token"
API_TOKEN = os.environ.get("API_TOKEN", "dev-token-change-me")

# Log masked token on startup for debugging
_masked_token = f"{API_TOKEN[:4]}...{API_TOKEN[-4:]}" if len(API_TOKEN) > 8 else "(short)"
print(f"[CONFIG] API_TOKEN: {_masked_token} (length: {len(API_TOKEN)})")

# Production mode: disable docs/redoc pages
# Set ENABLE_DOCS=true to enable them (for development)
ENABLE_DOCS = os.environ.get("ENABLE_DOCS", "false").lower() == "true"

app = FastAPI(
    title="Online Status API",
    description="API for tracking online/idle/offline status of users",
    version="1.0.0",
    # Disable docs in production
    docs_url="/docs" if ENABLE_DOCS else None,
    redoc_url="/redoc" if ENABLE_DOCS else None,
    openapi_url="/openapi.json" if ENABLE_DOCS else None,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security scheme for Bearer token
security = HTTPBearer()


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """Verify the Bearer token and return the token if valid."""
    token = credentials.credentials

    # Debug logging (remove in production)
    masked_received = f"{token[:4]}...{token[-4:]}" if len(token) > 8 else "(short)"
    masked_expected = f"{API_TOKEN[:4]}...{API_TOKEN[-4:]}" if len(API_TOKEN) > 8 else "(short)"
    print(f"[AUTH] Received token: {masked_received} (len={len(token)})")
    print(f"[AUTH] Expected token: {masked_expected} (len={len(API_TOKEN)})")
    print(f"[AUTH] Match: {token == API_TOKEN}")

    if token != API_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token


# =====================================================================
# FEATURE FLAGS
# =====================================================================
# Set to True to use mock data with random state changes (for testing)
# Set to False to use real heartbeat-based online detection
USE_MOCK_DATA = False

# Hardcoded randomization controls (only used when USE_MOCK_DATA=True)
RANDOMIZE_ON_FETCH = True       # if True, the list will be randomized on each request
FLIP_PROBABILITY = 0.5          # probability (0..1) for each friend to flip state when randomized
RANDOM_SEED = None              # set to an int for deterministic behavior, or None for non-deterministic

# Online timeout in seconds (user is considered offline if no heartbeat for this long)
ONLINE_TIMEOUT_SECONDS = 300    # 5 minutes


# --- Models ---    
class Friend(BaseModel):
    name: str
    state: str = Field(..., pattern="^(online|offline|idle)$")
    last_seen: str

class HeartbeatRequest(BaseModel):
    """Heartbeat request from frontend client."""
    uuid: str = Field(..., description="Unique client identifier")
    name: str = Field(..., description="Display name of the user")
    activity_state: str = Field(
        default="online",
        pattern="^(online|idle|unknown)$",
        description="User activity state: online (active), idle (AFK), unknown"
    )

class HeartbeatResponse(BaseModel):
    """Response to heartbeat request."""
    success: bool
    message: str
    timestamp: str


# --- In-memory stores ---

# Mock data for testing
def generate_initial_friends() -> List[dict]:
    """Create 4 mock friends with mixed states."""
    now = datetime.utcnow()
    return [
        {"name": "Alice", "state": "online", "last_seen": now.isoformat() + "Z"},
        {"name": "Bob", "state": "offline", "last_seen": (now - timedelta(minutes=5)).isoformat() + "Z"},
        {"name": "Charlie", "state": "offline", "last_seen": (now - timedelta(hours=1)).isoformat() + "Z"},
        {"name": "Diana", "state": "online", "last_seen": now.isoformat() + "Z"},
    ]

MOCK_FRIENDS = generate_initial_friends()

# Real user heartbeats: {uuid: {"name": str, "last_seen": datetime}}
USER_HEARTBEATS: Dict[str, dict] = {}


# --- Helper functions ---

def _now_iso():
    return datetime.utcnow().isoformat() + "Z"


def randomize_friends(current: List[dict], flip_probability: float = 0.5, seed: Optional[int] = None) -> List[dict]:
    """Randomly flip online/offline for some friends and update last_seen accordingly.

    If seed is provided, randomness is deterministic.
    """
    # clamp probability
    p = max(0.0, min(1.0, float(flip_probability)))
    rng = random.Random(seed)
    out = [dict(m) for m in current]
    for i in range(len(out)):
        if rng.random() < p:
            was_online = out[i].get("state") == "online"
            if was_online:
                out[i]["state"] = "offline"
                minutes_ago = rng.randint(1, 60)
                out[i]["last_seen"] = (datetime.utcnow() - timedelta(minutes=minutes_ago)).isoformat() + "Z"
            else:
                out[i]["state"] = "online"
                out[i]["last_seen"] = datetime.utcnow().isoformat() + "Z"
    return out


def get_real_friends_list() -> List[dict]:
    """Build friends list from real heartbeat data.

    A user is considered online if their last heartbeat was within ONLINE_TIMEOUT_SECONDS.
    The state reflects the user's activity:
    - "online": Active and recent heartbeat
    - "idle": AFK but recent heartbeat
    - "offline": No recent heartbeat
    """
    now = datetime.utcnow()
    friends = []
    for uuid, data in USER_HEARTBEATS.items():
        last_seen: datetime = data["last_seen"]
        elapsed = (now - last_seen).total_seconds()
        activity_state = data.get("activity_state", "online")

        # Determine final state
        if elapsed >= ONLINE_TIMEOUT_SECONDS:
            state = "offline"
        elif activity_state == "idle":
            state = "idle"
        else:
            state = "online"

        friends.append({
            "uuid": uuid,
            "name": data["name"],
            "state": state,
            "activity_state": activity_state,  # raw activity from client
            "last_seen": last_seen.isoformat() + "Z",
        })
    # Sort by name for consistent ordering
    friends.sort(key=lambda f: f["name"].lower())
    return friends


# --- Endpoints ---

@app.post("/heartbeat/", response_model=HeartbeatResponse)
async def post_heartbeat(request: HeartbeatRequest, token: str = Depends(verify_token)):
    """Receive a heartbeat from a frontend client.

    Requires Bearer token authentication.

    This updates the user's last_seen timestamp, making them appear online
    to other users who fetch the online_status endpoint.

    activity_state can be:
    - "online": User is actively using the computer
    - "idle": User is AFK (no mouse/keyboard input for 5+ minutes)
    - "unknown": Could not determine activity state
    """
    now = datetime.utcnow()
    USER_HEARTBEATS[request.uuid] = {
        "name": request.name,
        "last_seen": now,
        "activity_state": request.activity_state,
    }
    return HeartbeatResponse(
        success=True,
        message=f"Heartbeat received for {request.name} (state: {request.activity_state})",
        timestamp=now.isoformat() + "Z",
    )


@app.get("/online_status/", response_class=JSONResponse)
async def get_online_status(token: str = Depends(verify_token)):
    """Return the current friend online status list.

    Requires Bearer token authentication.

    When USE_MOCK_DATA is True, returns mock data with optional randomization.
    When USE_MOCK_DATA is False, returns real data based on heartbeats.
    """
    global MOCK_FRIENDS

    if USE_MOCK_DATA:
        # Mock mode: use static/randomized test data
        if RANDOMIZE_ON_FETCH:
            MOCK_FRIENDS = randomize_friends(MOCK_FRIENDS, flip_probability=FLIP_PROBABILITY, seed=RANDOM_SEED)
        return JSONResponse(content={"friends": MOCK_FRIENDS})
    else:
        # Real mode: build list from heartbeats
        friends = get_real_friends_list()
        return JSONResponse(content={"friends": friends})


@app.get("/healthz")
async def healthz():
    return {"ok": True}


# =====================================================================
# DEBUG / TEST ENDPOINTS (protected with token authentication)
# =====================================================================

@app.get("/debug/users", response_class=JSONResponse)
async def debug_get_users(token: str = Depends(verify_token)):
    """Debug endpoint: Show all registered users and their heartbeat data."""
    users = []
    now = datetime.utcnow()
    for uuid, data in USER_HEARTBEATS.items():
        last_seen: datetime = data["last_seen"]
        elapsed = (now - last_seen).total_seconds()
        activity_state = data.get("activity_state", "online")

        # Determine effective state
        if elapsed >= ONLINE_TIMEOUT_SECONDS:
            effective_state = "offline"
        elif activity_state == "idle":
            effective_state = "idle"
        else:
            effective_state = "online"

        users.append({
            "uuid": uuid,
            "name": data["name"],
            "activity_state": activity_state,
            "effective_state": effective_state,
            "last_seen": last_seen.isoformat() + "Z",
            "elapsed_seconds": round(elapsed, 1),
        })
    return JSONResponse(content={
        "total_users": len(users),
        "online_timeout_seconds": ONLINE_TIMEOUT_SECONDS,
        "use_mock_data": USE_MOCK_DATA,
        "users": users,
    })


@app.post("/debug/clear_users")
async def debug_clear_users(token: str = Depends(verify_token)):
    """Debug endpoint: Clear all user heartbeat data."""
    USER_HEARTBEATS.clear()
    return {"success": True, "message": "All user data cleared"}


@app.post("/debug/simulate_offline/{uuid}")
async def debug_simulate_offline(uuid: str, token: str = Depends(verify_token)):
    """Debug endpoint: Simulate a user going offline by setting their last_seen to 10 minutes ago."""
    if uuid not in USER_HEARTBEATS:
        return JSONResponse(status_code=404, content={"error": f"User {uuid} not found"})

    USER_HEARTBEATS[uuid]["last_seen"] = datetime.utcnow() - timedelta(minutes=10)
    return {"success": True, "message": f"User {uuid} simulated as offline"}


@app.post("/debug/simulate_idle/{uuid}")
async def debug_simulate_idle(uuid: str, token: str = Depends(verify_token)):
    """Debug endpoint: Simulate a user going idle (AFK) by setting their activity_state to idle."""
    if uuid not in USER_HEARTBEATS:
        return JSONResponse(status_code=404, content={"error": f"User {uuid} not found"})

    USER_HEARTBEATS[uuid]["activity_state"] = "idle"
    USER_HEARTBEATS[uuid]["last_seen"] = datetime.utcnow()  # keep them "connected" but idle
    return {"success": True, "message": f"User {uuid} simulated as idle"}


@app.post("/debug/simulate_active/{uuid}")
async def debug_simulate_active(uuid: str, token: str = Depends(verify_token)):
    """Debug endpoint: Simulate a user becoming active again."""
    if uuid not in USER_HEARTBEATS:
        return JSONResponse(status_code=404, content={"error": f"User {uuid} not found"})

    USER_HEARTBEATS[uuid]["activity_state"] = "online"
    USER_HEARTBEATS[uuid]["last_seen"] = datetime.utcnow()
    return {"success": True, "message": f"User {uuid} simulated as active"}


# =====================================================================
# DISABLED FOR PRODUCTION - Uncomment if needed for development
# =====================================================================
# @app.post("/debug/set_mock_mode/{enabled}")
# async def debug_set_mock_mode(enabled: bool, token: str = Depends(verify_token)):
#     """Debug endpoint: Toggle mock mode on/off at runtime."""
#     global USE_MOCK_DATA
#     USE_MOCK_DATA = enabled
#     return {"success": True, "use_mock_data": USE_MOCK_DATA}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
