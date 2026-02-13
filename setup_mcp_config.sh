#!/usr/bin/env bash
# Creates .claude/mcp.json in the specified directory so that wayland-mcp
# is only active when Claude Code is started from that directory.
#
# Usage (from a consuming project where wayland-mcp is a submodule):
#   $PROJECT_ROOT/tools/desktop-wayland-mcp-control/wayland-mcp/setup_mcp_config.sh \
#       "$PROJECT_ROOT/tools/desktop-wayland-mcp-control"
#
# If no argument is given, defaults to the parent of the script's directory
# (correct when the submodule is at <mcp-control-dir>/wayland-mcp/).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_CONTROL_DIR="${1:-$(dirname "${SCRIPT_DIR}")}"

# --- Validate inputs ---

if [[ -z "${MY_VENV_PYTHON_BIN:-}" ]]; then
  echo "ERROR: MY_VENV_PYTHON_BIN is not set. Expected path to venv python binary (e.g. /home/user/MY_PYTHON_VENV/bin/python3)."
  exit 1
fi

if [[ ! -x "${MY_VENV_PYTHON_BIN}" ]]; then
  echo "ERROR: MY_VENV_PYTHON_BIN=[${MY_VENV_PYTHON_BIN}] is not an executable file."
  exit 1
fi

if [[ ! -d "${MCP_CONTROL_DIR}" ]]; then
  echo "ERROR: MCP_CONTROL_DIR=[${MCP_CONTROL_DIR}] is not a directory."
  exit 1
fi

# --- Build the config ---

USER_ID="$(id -u)"
CLAUDE_DIR="${MCP_CONTROL_DIR}/.claude"
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
        "WAYLAND_DISPLAY": "wayland-0",
        "DISPLAY": ":0",
        "XDG_SESSION_TYPE": "wayland"
      }
    }
  }
}
JSONEOF

echo "MCP config written to [${MCP_JSON}]"
echo "wayland-mcp will activate only when Claude Code is started from [${MCP_CONTROL_DIR}]"
