#!/usr/bin/env python3
"""
Local testing script for the Online Status backend.

This script helps you manually test the heartbeat and online status endpoints.
Run the backend first with: python main.py

Usage:
    python test_backend.py

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
    0. Exit
"""

import requests
import uuid
import sys

BASE_URL = "http://localhost:8000"

# Generate a test UUID (or use a fixed one for consistent testing)
TEST_UUID = str(uuid.uuid4())
TEST_NAME = "TestUser"


def send_heartbeat(user_uuid: str = TEST_UUID, name: str = TEST_NAME, activity_state: str = "online"):
    """Send a heartbeat for a user."""
    try:
        resp = requests.post(
            f"{BASE_URL}/heartbeat/",
            json={"uuid": user_uuid, "name": name, "activity_state": activity_state}
        )
        resp.raise_for_status()
        print(f"✓ Heartbeat sent: {resp.json()}")
    except Exception as e:
        print(f"✗ Error: {e}")


def get_online_status():
    """Fetch the current online status list."""
    try:
        resp = requests.get(f"{BASE_URL}/online_status/")
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
        resp = requests.get(f"{BASE_URL}/debug/users")
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
        resp = requests.post(f"{BASE_URL}/debug/clear_users")
        resp.raise_for_status()
        print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_offline(user_uuid: str):
    """Simulate a user going offline."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_offline/{user_uuid}")
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_idle(user_uuid: str):
    """Simulate a user going idle (AFK)."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_idle/{user_uuid}")
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def simulate_active(user_uuid: str):
    """Simulate a user becoming active again."""
    try:
        resp = requests.post(f"{BASE_URL}/debug/simulate_active/{user_uuid}")
        if resp.status_code == 404:
            print(f"✗ User not found: {user_uuid}")
        else:
            resp.raise_for_status()
            print(f"✓ {resp.json()['message']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def toggle_mock_mode():
    """Toggle mock mode on/off."""
    try:
        # First get current state
        resp = requests.get(f"{BASE_URL}/debug/users")
        resp.raise_for_status()
        current_mock = resp.json()["use_mock_data"]

        # Toggle it
        new_state = not current_mock
        resp = requests.post(f"{BASE_URL}/debug/set_mock_mode/{str(new_state).lower()}")
        resp.raise_for_status()
        print(f"✓ Mock mode: {resp.json()['use_mock_data']}")
    except Exception as e:
        print(f"✗ Error: {e}")


def main():
    print(f"""
╔══════════════════════════════════════════════════╗
║         Online Status Backend Tester             ║
╠══════════════════════════════════════════════════╣
║  Test UUID: {TEST_UUID[:8]}...                    ║
║  Test Name: {TEST_NAME:<20}               ║
╚══════════════════════════════════════════════════╝

AFK Detection Logic:
  - Windows: GetLastInputInfo (mouse/keyboard idle time)
  - Linux: X11 XScreenSaver Extension
  - Threshold: 5 minutes of no input = idle/AFK
  
States:
  🟢 online  = Active (recent input)
  🟡 idle    = AFK (no input for 5+ min, but still connected)
  🔴 offline = Disconnected (no heartbeat for 5+ min)
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
        elif choice == "0":
            print("Bye!")
            sys.exit(0)
        else:
            print("Invalid choice")


if __name__ == "__main__":
    main()

