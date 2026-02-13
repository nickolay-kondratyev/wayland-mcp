# Security & Sketchiness Review: wayland-mcp

**Package**: `wayland-mcp` v0.4.0
**Source**: https://github.com/someaka/wayland-mcp
**Author**: someaka (+ 1 external contributor: iHad168 for KDE spectacle support)
**Review Date**: 2026-02-13
**Reviewer**: Claude Opus 4.6 (automated analysis)

---

## Executive Summary

**Overall Risk Level: MEDIUM-HIGH** - RUN ON VM not ON YOUR MAIN MACHINE.

This package is a **legitimate MCP (Model Context Protocol) server** that provides screen capture, mouse control, and keyboard input simulation for Wayland/Linux desktops. It does what it claims to do. However, the nature of what it does (full input device control) is inherently high-privilege and dangerous, and the setup script makes aggressive system-level permission changes.

**No malware detected.** No hidden backdoors, data exfiltration, obfuscated code, or malicious behavior found. The code is straightforward and readable.

---

## What This Package Does

1. **Screenshot capture** via multiple backends (ksnip, gnome-screenshot, grim, spectacle)
2. **Mouse control** (move, click, drag, scroll) via `evemu-event` (Linux input subsystem)
3. **Keyboard control** (type text, key combos) via `evemu-event`
4. **Image analysis** by sending screenshots to OpenRouter API (VLM models)
5. **Action chaining** (combine multiple input actions in sequence)
6. Exposes all of the above as MCP tools for AI agents to call

---

## Findings

### 1. CRITICAL: `setup_on_fedora_run_in_vm.sh` Makes Aggressive System Permission Changes

| Line | Action | Risk |
|------|--------|------|
| 53 | `sudo chmod u+s /usr/bin/evemu-event` | **SETUID bit** on a system binary - allows any user to run it as root |
| 59 | Adds NOPASSWD sudoers rule for evemu-event | Permanent passwordless sudo for this binary |
| 72 | `sudo usermod -aG input $USER` | Adds user to input group (reasonable) |
| 76-78 | `sudo chmod 666 /dev/input/event*` | **Makes ALL input devices world-writable** - any process can inject keystrokes/mouse events |
| 82-85 | Creates udev rule with `MODE="0666"` for all event devices | **Persists** world-writable permissions across reboots |

**Verdict**: The setup script is **overly permissive**. Setting `chmod 666` on all `/dev/input/event*` devices means **any unprivileged process** on the system can read your keystrokes (keylogger) or inject input. The setuid bit on `evemu-event` is also concerning. While these permissions are needed for the tool to function without root, they significantly weaken system security.

### 2. Network Communication - OpenRouter API Only

- The only outbound network calls go to `https://openrouter.ai/api/v1/chat/completions` (lines in `app.py:282` and `app.py:355`)
- Uses the `requests` library with proper timeouts (60s)
- API key is sourced from environment variable `OPENROUTER_API_KEY` or from `~/.roo/mcp.json`
- **Screenshots are base64-encoded and sent to a third-party API** - this means your screen content goes to OpenRouter's servers

**Verdict**: No suspicious network activity. But be aware that using the VLM analysis features sends your screenshots to OpenRouter.

### 3. API Key Handling

| Issue | Location | Severity |
|-------|----------|----------|
| Logs first 8 chars of API key | `app.py:332` | LOW - could leak partial key in logs |
| Hardcoded referer URL `https://github.com/your-repo` | `app.py:247,328` | NEGLIGIBLE - placeholder, not a real leak |
| Key read from config file at `~/.roo/mcp.json` | `server_mcp.py:42-44` | LOW - reasonable fallback |

**Verdict**: Minor API key hygiene issues but nothing dangerous.

### 4. Subprocess/Command Execution

The package spawns many subprocesses:
- `evemu-event` / `evemu-describe` - for input device control (expected)
- `ksnip`, `gnome-screenshot`, `grim`, `spectacle` - for screenshots (expected)
- `gsettings` - to toggle animations/sounds during capture (expected)
- `pactl` - to mute/unmute audio during capture (expected)
- `slurp`, `xrandr` - for region selection (expected)

**One minor concern** at `app.py:155-158`:
```python
result = subprocess.run(
    ["xrandr | grep ' connected'"],
    shell=True,  # <-- shell=True with hardcoded string
    ...
)
```
This uses `shell=True` but with a **hardcoded** command string (no user input), so it's not exploitable. Still, it's bad practice.

**Verdict**: No command injection vulnerabilities. All subprocess calls use list arguments (safe) except one hardcoded `shell=True` call.

### 5. File System Access

- Creates files at user-specified paths (screenshots)
- Creates a silent sound file at `/usr/share/sounds/silent/stereo/` or `~/.local/share/sounds/silent/stereo/`
- Logs to `/tmp/wayland-mcp.log`
- No path traversal vulnerabilities identified (paths come from MCP tool arguments, not arbitrary user web input)

**Verdict**: Clean.

### 6. Dependencies

| Dependency | Purpose | Risk |
|------------|---------|------|
| `requests` | HTTP client for OpenRouter API | Well-known, safe |
| `fastmcp` | MCP server framework | Relatively new but purpose-built |
| `Pillow` | Image processing (rulers) | Well-known, safe |

**Verdict**: Minimal dependency footprint. No suspicious or obscure packages.

### 7. Code Quality Observations

- No obfuscation, minification, or encoded payloads
- No eval(), exec(), or dynamic code execution
- No crypto-mining, phishing, or data harvesting code
- No hidden imports or conditional backdoors
- Code is straightforward and readable
- Some rough edges (placeholder URLs, inconsistent error handling) but nothing suspicious
- Module-level initialization in `server_mcp.py` (lines 50-53) means importing the module immediately tries to detect mouse/keyboard devices - could fail noisily

---

## Risk Matrix

| Category | Rating | Notes |
|----------|--------|-------|
| **Malware / Backdoors** | NONE | No malicious code found |
| **Data Exfiltration** | LOW | Screenshots sent to OpenRouter only when VLM features are explicitly used |
| **System Permission Escalation** | **HIGH** | setup_on_fedora_run_in_vm.sh sets world-writable permissions on ALL input devices |
| **Command Injection** | NONE | No injectable command execution |
| **Supply Chain Risk** | LOW | Minimal deps, all well-known |
| **Code Obfuscation** | NONE | Code is transparent and readable |
| **Crypto Mining** | NONE | No mining code |

---

## Recommendations

1. **DO NOT run `setup_on_fedora_run_in_vm.sh` as-is** on a shared or production machine. The `chmod 666` on all input devices is dangerous. On a personal single-user workstation, it's acceptable but understand the tradeoff.

2. **Be aware** that using VLM analysis features (capture_and_analyze, analyze_screenshot, compare_images) sends your screen content to OpenRouter's third-party API.

3. **Understand** that enabling this MCP server gives the connected AI model full mouse and keyboard control over your desktop. This is by design, but only use with trusted models and prompts.

4. **Log file** at `/tmp/wayland-mcp.log` may contain partial API keys (first 8 chars) and request metadata.

---

## Final Verdict

**SAFE TO USE with caveats.**

The package is legitimate, does what it claims, and contains no malicious code. The primary concerns are:
- The setup script's aggressive permission changes (security weakening, not malware)
- Screenshots being sent to a third-party API (OpenRouter) when VLM features are used
- The inherent risk of giving an AI agent mouse+keyboard control

These are all **known, documented trade-offs** of the tool's design, not hidden behaviors. The README even includes a security warning about input control. For a developer who understands these risks and is using it on a personal workstation, this package is reasonable to use.
