#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$REPO_DIR")"
WEBUI_DIR="$WORKSPACE_DIR/hermes-webui"
HERMES_DIR="$WORKSPACE_DIR/hermes-agent-core"
PYTHON="$WORKSPACE_DIR/hermes-venv/bin/python"
ENV_FILE="$WORKSPACE_DIR/.env"
LOG_DIR="$WORKSPACE_DIR/logs"
SESSION_NAME=hermes-webui

if [[ ! -f "$ENV_FILE" || ! -x "$PYTHON" || ! -f "$WEBUI_DIR/bootstrap.py" ]]; then
  echo "Setup is incomplete. Run: $REPO_DIR/setup.sh" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

mkdir -p "$LOG_DIR" "${HERMES_HOME:-$WORKSPACE_DIR/.hermes}"
export HERMES_HOME="${HERMES_HOME:-$WORKSPACE_DIR/.hermes}"
export HERMES_WEBUI_HOST="${HERMES_WEBUI_HOST:-${HOST:-0.0.0.0}}"
export HERMES_WEBUI_PORT="${HERMES_WEBUI_PORT:-${WEBUI_PORT:-8000}}"
export HERMES_WEBUI_AGENT_DIR="${HERMES_WEBUI_AGENT_DIR:-$HERMES_DIR}"
export HERMES_WEBUI_PYTHON="${HERMES_WEBUI_PYTHON:-$PYTHON}"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SESSION_NAME"
fi

for port in "$HERMES_WEBUI_PORT" 5000; do
  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  [[ -z "$pids" ]] || kill $pids 2>/dev/null || true
done

tmux new-session -d -s "$SESSION_NAME" \
  "cd '$WEBUI_DIR' && exec '$PYTHON' bootstrap.py --host '$HERMES_WEBUI_HOST' --foreground --no-browser --skip-agent-install >> '$LOG_DIR/webui.log' 2>&1"

health_url="http://127.0.0.1:${HERMES_WEBUI_PORT}/health"
for _ in {1..15}; do
  if curl --fail --silent --show-error --max-time 2 "$health_url" >/dev/null 2>&1; then
    if [[ -n "${CODESPACE_NAME:-}" ]] && command -v gh >/dev/null 2>&1; then
      gh codespace ports visibility "${HERMES_WEBUI_PORT}:public" -c "$CODESPACE_NAME" || true
    fi
    echo "Hermes WebUI is ready at $health_url"
    echo "Run Steel test: $PYTHON $REPO_DIR/test_steel.py"
    echo "Monitor logs: tail -f $LOG_DIR/webui.log"
    exit 0
  fi
  sleep 2
done

echo "WebUI did not become healthy within 30 seconds." >&2
tail -n 80 "$LOG_DIR/webui.log" >&2 || true
exit 1