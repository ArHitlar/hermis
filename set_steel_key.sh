#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(dirname "$REPO_DIR")/.env"
[[ -f "$ENV_FILE" ]] || cp "$REPO_DIR/.env.example" "$ENV_FILE"

read -r -s -p "Paste STEEL_API_KEY (input hidden): " steel_key
printf '\n'
[[ -n "$steel_key" ]] || { echo "No key entered." >&2; exit 1; }

STEEL_API_KEY="$steel_key" python3 - "$ENV_FILE" <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
key = os.environ["STEEL_API_KEY"]
lines = path.read_text().splitlines()
for index, line in enumerate(lines):
    if line.startswith("STEEL_API_KEY="):
        lines[index] = f"STEEL_API_KEY={key}"
        break
else:
    lines.insert(0, f"STEEL_API_KEY={key}")
path.write_text("\n".join(lines) + "\n")
PY

chmod 600 "$ENV_FILE"
unset steel_key
echo "Steel key saved securely. Test it with:"
echo "  $REPO_DIR/../hermes-venv/bin/python $REPO_DIR/test_steel.py"