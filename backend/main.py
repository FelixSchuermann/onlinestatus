import os
import json
import random
from datetime import datetime, timedelta
from typing import List, Optional

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

# --- Config ---
origins = ["*"]

# Hardcoded randomization controls (change here to control mock behavior)
RANDOMIZE_ON_FETCH = True       # if True, the list will be randomized on each request
FLIP_PROBABILITY = 0.5          # probability (0..1) for each friend to flip state when randomized
RANDOM_SEED = None              # set to an int for deterministic behavior, or None for non-deterministic

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Models ---
class Friend(BaseModel):
    name: str
    state: str = Field(..., regex="^(online|offline)$")
    last_seen: str

# --- Helper functions ---

def _now_iso():
    return datetime.utcnow().isoformat() + "Z"


def generate_initial_friends() -> List[dict]:
    """Create 4 mock friends with mixed states."""
    now = datetime.utcnow()
    return [
        {"name": "Alice", "state": "online", "last_seen": now.isoformat() + "Z"},
        {"name": "Bob", "state": "offline", "last_seen": (now - timedelta(minutes=5)).isoformat() + "Z"},
        {"name": "Charlie", "state": "offline", "last_seen": (now - timedelta(hours=1)).isoformat() + "Z"},
        {"name": "Diana", "state": "online", "last_seen": now.isoformat() + "Z"},
    ]

# In-memory store for now
FRIENDS = generate_initial_friends()


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

# --- Endpoints ---
@app.get("/online_status/", response_class=JSONResponse)
async def get_online_status():
    """Return the current friend online status list (in-memory).

    This endpoint does not accept parameters. Randomization behavior is controlled
    by the hardcoded constants at the top of the file.
    """
    global FRIENDS
    if RANDOMIZE_ON_FETCH:
        FRIENDS = randomize_friends(FRIENDS, flip_probability=FLIP_PROBABILITY, seed=RANDOM_SEED)
    return JSONResponse(content={"friends": FRIENDS})

@app.get("/healthz")
async def healthz():
    return {"ok": True}

if __name__ == "__main__":
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
