#!/usr/bin/env python3
"""
Local testing script for the Online Status backend.

This script helps you manually test the heartbeat and online status endpoints.
Run the backend first with: python main.py

Usage:
    python test_backend.py

    # Or with custom token:
    API_TOKEN=your-token python test_backend.py

Commands:
    1. Send heartbeat for test user (online)
    2. Send heartbeat for test user (idle/AFK)
    3. Get online status
    4. Show all users (debug)
    5. Clear all users
    6. Simulate user going offline
    7. Simulate user going idle
    8. Simulate user becoming active
    9. Toggle mock mode
    10. Add second test user
    11. Change API token
    0. Exit
"""

import requests
import urllib3
import uuid
import sys
import os

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Set to False to skip SSL certificate verification (for self-signed certs)
VERIFY_SSL = False

BASE_URL = os.environ.get("BASE_URL", "https://79.133.50.43:8443")

# API Token - default matches the dev token in main.py
API_TOKEN = os.environ.get("API_TOKEN", "e0ee13c95baad6354422ad4217db9faad7439447335ea8fd86d52c4d433cb9e3")

# Generate a test UUID (or use a fixed one for consistent testing)
TEST_UUID = str(uuid.uuid4())
TEST_NAME = "TestUser"


def get_headers():
    """Get authorization headers with Bearer token."""
    return {"Authorization": f"Bearer {API_TOKEN}"}


def send_heartbeat(user_uuid: str = TEST_UUID, name: str = TEST_NAME, activity_state: str = "online"):
    """Send a heartbeat for a user."""
    try:
        resp = requests.post(
            f"{BASE_URL}/heartbeat/",
            json={"uuid": user_uuid, "name": name, "activity_state": activity_state},
            headers=get_headers(),
            verify=VERIFY_SSL
        )
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        resp.raise_for_status()
        print(f"✓ Heartbeat sent: {resp.json()}")
    except Exception as e:
        print(f"✗ Error: {e}")


def get_online_status():
    """Fetch the current online status list."""
    try:
        resp = requests.get(f"{BASE_URL}/online_status/", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        resp.raise_for_status()
        data = resp.json()
        friends = data.get("friends", [])
        print(f"\n{'='*50}")
        print(f"Online Status ({len(friends)} users)")
        print('='*50)
        for f in friends:
            state = f["state"]
            if state == "online":
                status = "🟢"
            elif state == "idle":
                status = "🟡"
            else:
                status = "🔴"
            print(f"  {status} {f['name']} [{state}] (last seen: {f['last_seen']})")
        if not friends:
            print("  (no users yet)")
        print('='*50)
    except Exception as e:
        print(f"✗ Error: {e}")


def debug_users():
    """Show debug info for all users."""
    try:
        resp = requests.get(f"{BASE_URL}/debug/users", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        resp.raise_for_status()
        data = resp.json()
        print(f"\n{'='*50}")
        print(f"Debug: All Users ({data['total_users']} total)")
        print(f"Mock mode: {data['use_mock_data']}")
        print(f"Online timeout: {data['online_timeout_seconds']}s")
        print('='*50)
        for u in data["users"]:
            state = u["effective_state"]
            if state == "online":
                status = "🟢 online"
            elif state == "idle":
                status = "🟡 idle"
            else:
                status = "🔴 offline"
            print(f"  UUID: {u['uuid']}")
            print(f"  Name: {u['name']}")
            print(f"  Activity: {u['activity_state']}")
            print(f"  Effective: {status}")
            print(f"  Last seen: {u['last_seen']} ({u['elapsed_seconds']}s ago)")
            print("  ---")
        if not data["users"]:
            print("  (no users)")
        print('='*50)
    except Exception as e:
        print(f"✗ Error: {e}")


def clear_users():
    """Clear all user data."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/clear_users", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        resp.raise_for_status()
        print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_offline(user_uuid: str):
    """Simulate a user going offline."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_offline/{user_uuid}", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
            print(f"  → Send a heartbeat first (option 1 or 2) to create the user")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_idle(user_uuid: str):
    """Simulate a user going idle (AFK)."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_idle/{user_uuid}", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
            print(f"  → Send a heartbeat first (option 1 or 2) to create the user")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_active(user_uuid: str):
    """Simulate a user becoming active again."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_active/{user_uuid}", headers=get_headers(), verify=VERIFY_SSL)
        if resp.status_code == 401:
            print(f"✗ Unauthorized - check your API token")
            return
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def toggle_mock_mode():
    """Toggle mock mode on/off. (DISABLED IN PRODUCTION)"""
    print("✗ This endpoint is disabled in production")
    return
    # Uncomment below if endpoint is re-enabled on the server
    # try:
    #     # First get current state
    #     resp = requests.get(f"{BASE_URL}/debug/users", headers=get_headers(), verify=VERIFY_SSL)
    #     resp.raise_for_status()
    #     current_mock = resp.json()["use_mock_data"]
    #
    #     # Toggle it
    #     new_state = not current_mock
    #     resp = requests.post(f"{BASE_URL}/debug/set_mock_mode/{str(new_state).lower()}", headers=get_headers(), verify=VERIFY_SSL)
    #     resp.raise_for_status()
    #     print(f"✓ Mock mode: {resp.json()['use_mock_data']}")
    # except Exception as e:
    #     print(f"✗ Error: {e}")


def change_token():
    """Change the API token."""
    global API_TOKEN
    new_token = input("Enter new API token: ").strip()
    if new_token:
        API_TOKEN = new_token
        print(f"✓ Token updated")
    else:
        print("✗ Token not changed (empty input)")


def main():
    print(f"""
╔══════════════════════════════════════════════════╗
║         Online Status Backend Tester             ║
╠══════════════════════════════════════════════════╣
║  Test UUID: {TEST_UUID[:8]}...                    ║
║  Test Name: {TEST_NAME:<20}               ║
║  Base URL:  {BASE_URL:<27} ║
║  Token:     {API_TOKEN[:20]}{"..." if len(API_TOKEN) > 20 else " "*(24-len(API_TOKEN))} ║
╚══════════════════════════════════════════════════╝

AFK Detection Logic:
  - Windows: GetLastInputInfo (mouse/keyboard idle time)
  - Linux: X11 XScreenSaver Extension
  - Threshold: 5 minutes of no input = idle/AFK
  
States:
  🟢 online  = Active (recent input)
  🟡 idle    = AFK (no input for 5+ min, but still connected)
  🔴 offline = Disconnected (no heartbeat for 5+ min)
  
Authentication:
  All /heartbeat/ and /online_status/ endpoints require Bearer token.
  Debug endpoints (/debug/*) do not require authentication.
""")

    while True:
        print("\nCommands:")
        print("  1. Send heartbeat (online/active)")
        print("  2. Send heartbeat (idle/AFK)")
        print("  3. Get online status")
        print("  4. Show all users (debug)")
        print("  5. Clear all users")
        print("  6. Simulate test user going offline")
        print("  7. Simulate test user going idle")
        print("  8. Simulate test user becoming active")
        print("  9. Toggle mock mode")
        print("  10. Add second test user")
        print("  11. Change API token")
        print("  0. Exit")

        choice = input("\nChoice: ").strip()

        if choice == "1":
            send_heartbeat(activity_state="online")
        elif choice == "2":
            send_heartbeat(activity_state="idle")
        elif choice == "3":
            get_online_status()
        elif choice == "4":
            debug_users()
        elif choice == "5":
            clear_users()
        elif choice == "6":
            simulate_offline(TEST_UUID)
        elif choice == "7":
            simulate_idle(TEST_UUID)
        elif choice == "8":
            simulate_active(TEST_UUID)
        elif choice == "9":
            toggle_mock_mode()
        elif choice == "10":
            # Add a second user
            second_uuid = str(uuid.uuid4())
            send_heartbeat(second_uuid, "SecondUser", "online")
            print(f"  (UUID: {second_uuid[:8]}...)")
        elif choice == "11":
            change_token()
        elif choice == "0":
            print("Bye!")
            sys.exit(0)
        else:
            print("Invalid choice")


if __name__ == "__main__":
    main()

