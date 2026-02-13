#!/usr/bin/env bash
# Creates .claude/mcp.json in this directory so that wayland-mcp
# is active when Claude Code is started from this directory.
#
# Usage:
#   ./setup_mcp_config.sh
#
# The generated .claude/mcp.json is git-ignored since it contains
# machine-specific paths (venv python binary, user ID).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Validate inputs ---

if [[ -z "${MY_VENV_PYTHON_BIN:-}" ]]; then
  echo "ERROR: MY_VENV_PYTHON_BIN is not set. Expected path to venv python binary (e.g. /home/user/MY_PYTHON_VENV/bin/python3)."
  exit 1
fi

if [[ ! -x "${MY_VENV_PYTHON_BIN}" ]]; then
  echo "ERROR: MY_VENV_PYTHON_BIN=[${MY_VENV_PYTHON_BIN}] is not an executable file."
  exit 1
fi

# --- Detect Wayland session values ---

USER_ID="$(id -u)"

# Use actual WAYLAND_DISPLAY from session instead of hardcoding
WAYLAND_DISPLAY_VALUE="${WAYLAND_DISPLAY:-}"
if [[ -z "${WAYLAND_DISPLAY_VALUE}" ]]; then
  WAYLAND_DISPLAY_VALUE="wayland-0"
  echo "WARN: WAYLAND_DISPLAY is not set, falling back to [${WAYLAND_DISPLAY_VALUE}]. If MCP fails to connect, verify with: echo \$WAYLAND_DISPLAY"
fi

# --- Build the config ---

CLAUDE_DIR="${SCRIPT_DIR}/.claude"
MCP_JSON="${CLAUDE_DIR}/mcp.json"

mkdir -p "${CLAUDE_DIR}"

cat > "${MCP_JSON}" <<JSONEOF
{
  "mcpServers": {
    "wayland-mcp": {
      "command": "${MY_VENV_PYTHON_BIN}",
      "args": ["-m", "wayland_mcp.server_mcp"],
      "env": {
        "XDG_RUNTIME_DIR": "/run/user/${USER_ID}",
        "WAYLAND_DISPLAY": "${WAYLAND_DISPLAY_VALUE}",
        "DISPLAY": "${DISPLAY:-:0}",
        "XDG_SESSION_TYPE": "wayland"
      }
    }
  }
}
JSONEOF

echo "MCP config written to [${MCP_JSON}]"
echo "Start Claude Code from [${SCRIPT_DIR}] for wayland-mcp to activate."
