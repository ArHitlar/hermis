#!/usr/bin/env python3
"""Create and release a minimal Steel session when a real key is configured."""

import os
import sys
from pathlib import Path

from dotenv import load_dotenv


repo_dir = Path(__file__).resolve().parent
workspace_dir = repo_dir.parent
load_dotenv(workspace_dir / ".env")
load_dotenv(repo_dir / ".env", override=False)

api_key = os.getenv("STEEL_API_KEY", "").strip()
placeholder_values = {"", "your_steel_api_key_here", "replace_me", "changeme"}
if api_key.lower() in placeholder_values:
    print(f"STEEL_API_KEY is not configured; add it to {workspace_dir / '.env'}.")
    sys.exit(0)

from steel import Steel


client = Steel(
    steel_api_key=api_key,
    base_url=os.getenv("STEEL_BASE_URL", "https://api.steel.dev").strip(),
)
session_id = None
try:
    session = client.sessions.create(headless=True)
    session_id = getattr(session, "id", None) or getattr(session, "session_id", None)
    print(f"Steel connectivity OK; created session {session_id}.")
finally:
    if session_id:
        try:
            client.sessions.release(session_id)
            print("Steel test session released.")
        except Exception as error:
            print(f"Warning: could not release test session: {error}", file=sys.stderr)
    client.close()