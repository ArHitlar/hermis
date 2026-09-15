#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$REPO_DIR")"
HERMES_DIR="$WORKSPACE_DIR/hermes-agent-core"
WEBUI_DIR="$WORKSPACE_DIR/hermes-webui"
VENV_DIR="$WORKSPACE_DIR/hermes-venv"
ENV_FILE="$WORKSPACE_DIR/.env"

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

echo "[1/7] Installing system prerequisites..."
"${SUDO[@]}" apt-get update
"${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl git jq lsof net-tools ripgrep tmux wget \
  python3.12 python3.12-venv

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  echo "[2/7] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
else
  echo "[2/7] uv already installed."
fi

clone_or_update() {
  local url="$1"
  local directory="$2"
  if [[ -d "$directory/.git" ]]; then
    git -C "$directory" fetch --depth 1 origin
    git -C "$directory" reset --hard origin/HEAD
  else
    rm -rf "$directory"
    git clone --depth 1 "$url" "$directory"
  fi
}

echo "[3/7] Fetching upstream Hermes projects..."
clone_or_update https://github.com/NousResearch/hermes-agent.git "$HERMES_DIR"
clone_or_update https://github.com/nesquena/hermes-webui.git "$WEBUI_DIR"

echo "[4/7] Creating Python 3.12 environment..."
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  /usr/bin/python3.12 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel

echo "[5/7] Installing Hermes, WebUI, Steel, and browser packages..."
UV_LINK_MODE=copy uv pip install --python "$VENV_DIR/bin/python" \
  -e "$HERMES_DIR" -e "$WEBUI_DIR" \
  steel-sdk playwright requests python-dotenv
"$VENV_DIR/bin/python" -m playwright install chromium

echo "[6/7] Creating local configuration..."
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$REPO_DIR/.env.example" "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

echo "[7/7] Starting Hermes WebUI..."
exec "$REPO_DIR/start_hermes.sh"