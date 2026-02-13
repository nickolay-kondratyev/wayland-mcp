# Using wayland-mcp with Claude Code in a VM

Quick guide to get screenshot capture + mouse/keyboard control working with Claude Code inside a Linux VM.

> Running in a VM is recommended - the setup script opens up input device permissions, which is fine in an isolated VM but risky on a bare-metal workstation.

---

## 1. VM Requirements

- Linux VM with a **Wayland** desktop session (GNOME on Wayland is easiest)
- At least one screenshot tool installed: `gnome-screenshot`, `grim`, `ksnip`, or `spectacle`
- Python 3.8+
- `evemu-tools` (installed automatically by `setup_on_fedora.sh` on Fedora; see manual instructions below for other distros)

The setup script auto-installs `evemu` and `gnome-screenshot` on Fedora (via dnf). For **Ubuntu/Debian**, install manually:
```bash
sudo apt install evemu-tools gnome-screenshot
```

## 2. Install wayland-mcp (From Reviewed Source)

We install from our own audited copy of the source rather than pulling from PyPI/uvx, so we run exactly the code we reviewed.

```bash
# Clone our reviewed fork (not upstream)
git clone git@github.com:nickolay-kondratyev/wayland-mcp.git
cd wayland-mcp

# Pin to the exact reviewed commit
git checkout 7c49d4c

# Install from local source
pip install -e .
```

> **Why from source?** Running `uvx wayland-mcp` or `pip install wayland-mcp` pulls whatever is currently published to PyPI, which could differ from what we reviewed. Installing from our pinned commit guarantees we run the audited code.

## 3. Run the Setup Script (Input Device Permissions)

This grants permissions for mouse/keyboard simulation via `evemu-event`. Safe inside a VM:

```bash
cd wayland-mcp
chmod +x setup_on_fedora.sh
./setup_on_fedora.sh
```

What it does:
- Installs `evemu` and `gnome-screenshot` if missing (auto-detects dnf/apt/brew)
- Sets permissions so `evemu-event` works without sudo
- Makes `/dev/input/event*` devices writable (needed for input simulation)

## 4. Verify It Works

```bash
# Should list a mouse device without errors
python -c "from wayland_mcp.mouse_utils import MouseController; m = MouseController(); print(f'Mouse device: {m.device}')"

# Should list a keyboard device without errors
python -c "from wayland_mcp.keyboard_utils import KeyboardController; k = KeyboardController(); print(f'Keyboard device: {k.device}')"
```

## 5. Configure Claude Code

Add the MCP server to your Claude Code config. Edit `~/.claude.json` (global) or `.claude/mcp.json` (project-level).

Since we installed from source, point directly to the local Python that has the package:

```json
{
  "mcpServers": {
    "wayland-mcp": {
      "command": "python",
      "args": ["-m", "wayland_mcp.server_mcp"],
      "env": {
        "XDG_RUNTIME_DIR": "/run/user/1000",
        "WAYLAND_DISPLAY": "wayland-0",
        "DISPLAY": ":0",
        "XDG_SESSION_TYPE": "wayland"
      }
    }
  }
}
```

If you installed into a **venv**, use the full path to that venv's python:
```json
{
  "mcpServers": {
    "wayland-mcp": {
      "command": "/home/<user>/wayland-mcp/.venv/bin/python",
      "args": ["-m", "wayland_mcp.server_mcp"],
      "env": {
        "XDG_RUNTIME_DIR": "/run/user/1000",
        "WAYLAND_DISPLAY": "wayland-0",
        "DISPLAY": ":0",
        "XDG_SESSION_TYPE": "wayland"
      }
    }
  }
}
```

> **Note**: The `OPENROUTER_API_KEY` and `VLM_MODEL` env vars are **not needed**. Those are only for the VLM image analysis features. Claude Code can analyze screenshots itself - you just need the capture and input control tools.

### Verify your UID for XDG_RUNTIME_DIR

```bash
# Should print your numeric user ID (typically 1000)
id -u
```

If it's not 1000, update the `XDG_RUNTIME_DIR` value to `/run/user/<your-uid>`.

## 6. Available Tools in Claude Code

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

## 7. Example Usage in Claude Code

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
