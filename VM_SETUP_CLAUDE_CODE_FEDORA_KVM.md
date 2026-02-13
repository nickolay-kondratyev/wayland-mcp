# Using wayland-mcp with Claude Code in a VM

Quick guide to get screenshot capture + mouse/keyboard control working with Claude Code inside a Linux VM.

> Running in a VM is recommended - the setup script opens up input device permissions, which is fine in an isolated VM but risky on a bare-metal workstation.

---

## 1. VM Requirements

- Linux VM with a **Wayland** desktop session (GNOME on Wayland is easiest)
- Python 3.8+
- `evemu-tools` (installed automatically by `setup_on_fedora.sh` on Fedora; see manual instructions below for other distros)
- Virtual environment variables set:
  - `MY_VENV_PYTHON_DIR` — path to the venv directory (e.g. `/home/<user>/MY_PYTHON_VENV`)
  - `MY_VENV_PYTHON_BIN` — path to the venv python binary (e.g. `/home/<user>/MY_PYTHON_VENV/bin/python3`)
  - `MY_VENV_PIP` — path to the venv pip binary (e.g. `/home/<user>/MY_PYTHON_VENV/bin/pip`)

The setup script auto-installs `evemu` and a screenshot tool (`gnome-screenshot` as default) if none of the supported ones (`gnome-screenshot`, `grim`, `ksnip`, `spectacle`) are found.

## 2. Run the Setup Script

The setup script handles everything: installs system packages, sets input device permissions, installs wayland-mcp into your venv, and prints the Claude Code MCP configuration.

```bash
git clone git@github.com:nickolay-kondratyev/wayland-mcp.git
cd wayland-mcp
chmod +x setup_on_fedora.sh
./setup_on_fedora.sh
```

What it does:
- Validates that `MY_VENV_PYTHON_BIN` and `MY_VENV_PIP` are set and executable
- Installs `evemu` and `gnome-screenshot` if missing (auto-detects dnf/apt/brew)
- Sets permissions so `evemu-event` works without sudo
- Makes `/dev/input/event*` devices writable (needed for input simulation)
- Installs wayland-mcp into the venv via `$MY_VENV_PIP install -e .`
- Verifies mouse and keyboard device detection
- Prints the Claude Code MCP configuration JSON with correct paths

> **Why from source?** Running `uvx wayland-mcp` or `pip install wayland-mcp` pulls whatever is currently published to PyPI. Installing from source ensures we run our own code.

## 3. Configure Claude Code

The setup script prints the exact JSON to use. Add it to `~/.claude.json` (global) or `.claude/mcp.json` (project-level).

The configuration uses `$MY_VENV_PYTHON_BIN` as the command, so the MCP server runs from your venv:

```json
{
  "mcpServers": {
    "wayland-mcp": {
      "command": "$MY_VENV_PYTHON_BIN",
      "args": ["-m", "wayland_mcp.server_mcp"],
      "env": {
        "XDG_RUNTIME_DIR": "/run/user/<your-uid>",
        "WAYLAND_DISPLAY": "wayland-0",
        "DISPLAY": ":0",
        "XDG_SESSION_TYPE": "wayland"
      }
    }
  }
}
```

> Replace `$MY_VENV_PYTHON_BIN` with the actual path (the setup script output will have it filled in).

> **Note**: The `OPENROUTER_API_KEY` and `VLM_MODEL` env vars are **not needed**. Those are only for the VLM image analysis features. Claude Code can analyze screenshots itself - you just need the capture and input control tools.

## 4. Available Tools in Claude Code

Once connected, Claude Code will have access to these MCP tools:

| Tool | What it does |
|------|-------------|
| `capture_screenshot` | Takes a screenshot (saved as PNG with measurement rulers) |
| `move_mouse(x, y)` | Move cursor to absolute screen coordinates |
| `click_mouse()` | Left-click at current cursor position |
| `drag_mouse(x1, y1, x2, y2)` | Drag from one point to another |
| `scroll_mouse(amount)` | Scroll wheel (positive=up, negative=down) |
| `execute_action(action)` | Chained actions, e.g. `"chain:click:100,200;type:hello;press:Enter"` |

The `analyze_screenshot`, `compare_images`, and `capture_and_analyze` tools exist but require an OpenRouter API key - skip these since Claude Code can analyze images directly.

## 5. Example Usage in Claude Code

Once configured, you can ask Claude Code things like:

- "Take a screenshot of my desktop"
- "Click on the terminal window at coordinates 500, 300"
- "Type 'hello world' and press Enter"
- "Take a screenshot, then click the button at 200, 150"

## Troubleshooting

**"No suitable mouse device found"**
- Run `ls -la /dev/input/event*` - devices should be writable (`rw-rw-rw-`)
- Re-run `./setup_on_fedora.sh` if permissions were reset

**"No suitable keyboard device found"**
- Same as above - `setup_on_fedora.sh` must have completed successfully

**Screenshot tools fail**
- Verify you're in a Wayland session: `echo $XDG_SESSION_TYPE` should print `wayland`
- Verify at least one capture tool is installed: `which gnome-screenshot grim ksnip spectacle`

**MCP server won't connect**
- Check that the `env` vars in your Claude Code config match your VM's session
- Run `echo $WAYLAND_DISPLAY` in the VM terminal to get the correct value
