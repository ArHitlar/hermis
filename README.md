# Hermes Codespace Setup

This repository documents the local Hermes Agent + Hermes WebUI setup used by
this Codespace. The upstream WebUI runs the Hermes Agent in-process, so there
is one service on port `8000`, not a separate port-5000 backend.

## One-Command Setup

```bash
./setup.sh
```

This installs prerequisites, fetches Hermes Agent and WebUI, creates the
Python 3.12 environment, installs dependencies and Chromium, creates
`/workspaces/.env`, and starts the WebUI on port `8000`. It is safe to rerun.
The upstream repositories are pinned to the revisions tested with this setup.

Open forwarded port `8000` in Codespaces. Set `HERMES_WEBUI_PASSWORD` in
`/workspaces/.env` before making the port public.

Useful checks:

```bash
../hermes-venv/bin/hermes --version
../hermes-venv/bin/python ./test_steel.py
tail -f ../logs/webui.log
```

To enter a Steel key without putting it in chat or shell history:

```bash
./set_steel_key.sh
../hermes-venv/bin/python ./test_steel.py
```

The key is stored only in the protected `/workspaces/.env` file. Remove its
value after testing.

## Setup Notes

The setup was intentionally adapted to the repositories' current behavior:

- Hermes requires Python `>=3.11,<3.14`; this container's default Python is
	3.14.2, so the shared environment uses `/usr/bin/python3.12`.
- Hermes WebUI defaults to port `8787` and starts Hermes in-process. The
	launcher overrides it to `0.0.0.0:8000` for Codespaces.
- `STEEL_API_KEY` is optional. The Steel test exits cleanly with an instruction
	when no real key is configured.

## Issue and Fix Log

| Issue | Diagnosis | Resolution |
| --- | --- | --- |
| Hermes would resolve against unsupported Python 3.14 | `pyproject.toml` caps Python at `<3.14` | Installed and used a Python 3.12 virtual environment |
| The prompt described separate backend and WebUI services | WebUI README says chat runs in-process; `bootstrap.py` owns the server | Launch only the WebUI process and health-check `/health` on port 8000 |
| Requested `requirements.txt` installation was too broad for Hermes | Both projects have project metadata and pinned dependencies | Installed both editable projects plus Steel/Playwright with `uv pip` |
| Steel connectivity cannot be tested without a credential | SDK requires `steel_api_key` for API calls | `test_steel.py` warns without a key and creates/releases one session when configured |
| WebUI bootstrap tried to clone a second Hermes checkout | Bootstrap auto-installs when `--skip-agent-install` is absent | Launcher passes the supported skip flag and reuses `/workspaces/hermes-venv` |
| WebUI could not discover the editable Hermes checkout | Discovery needs a `run_agent.py` directory or a PATH launcher; the venv launcher was not on the shell PATH | Launcher exports `HERMES_WEBUI_AGENT_DIR` and `HERMES_WEBUI_PYTHON` explicitly |
| Public bind warned that no password was set | WebUI deliberately warns when `0.0.0.0` is used without authentication | Set `HERMES_WEBUI_PASSWORD` in `/workspaces/.env` before exposing the forwarded port publicly |

For future changes, add the symptom, the cheapest check that confirmed it, and
the smallest working fix to this log before repeating the setup.