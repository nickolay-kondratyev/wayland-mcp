# Implementation Review: simplify-setup

**Verdict: PASS** -- ready for convergence with one IMPORTANT item to acknowledge.

---

## Summary

The change renames `setup.sh` to `setup_on_fedora.sh`, adds an `install_if_missing` function that auto-detects the package manager (dnf/apt/apt-get/brew) and auto-installs `evemu` and `gnome-screenshot`, and updates all documentation references. The existing permissions logic (setuid, sudoers, input group, chmod, udev rules) is preserved unchanged.

The implementation is clean, focused, and follows KISS. The `install_if_missing` function has proper error handling: required parameter validation, post-install verification, and clear error messages.

---

## No CRITICAL Issues

No security, correctness, or data loss issues found.

---

## IMPORTANT Issues

### 1. Cross-distro confusion: script name vs actual capability

**File**: `/home/nickolaykondratyev/git_repos/nickolay-kondratyev_wayland-mcp/setup_on_fedora.sh` (line 48)

The script is named `setup_on_fedora.sh`, but `install_if_missing` supports apt, apt-get, and brew. Meanwhile, the package name `evemu` is Fedora-specific -- on Debian/Ubuntu the package is `evemu-tools`. If someone runs this on Ubuntu, the apt path will be taken, `sudo apt install -y evemu` will fail (no such package), and then the post-install check will correctly `exit 1`.

The function **does** handle this gracefully (exits with a clear error), so there is no silent failure. However, `VM_SETUP_CLAUDE_CODE.md` line 50 says:

```
- Installs `evemu` and `gnome-screenshot` if missing (auto-detects dnf/apt/brew)
```

This could mislead Debian/Ubuntu users into thinking the script works for their distro. Consider either:
- **(a)** Changing line 50 to say `auto-detects dnf; falls back to apt/brew but uses Fedora package names` -- OR
- **(b)** Keeping it as-is, since the script name `setup_on_fedora.sh` already signals Fedora-only intent.

**Recommendation**: Option (b) is acceptable. The script name is clear enough, and the error path is correct. No code change required, but worth a conscious acknowledgement.

### 2. SECURITY_REVIEW.md line numbers are stale

**File**: `/home/nickolaykondratyev/git_repos/nickolay-kondratyev_wayland-mcp/SECURITY_REVIEW.md` (lines 38-42)

The findings table references line numbers from the old `setup.sh` (16, 21, 34, 38-39, 44-45). After adding the `install_if_missing` function (~33 new lines), these shifted to approximately lines 54, 59, 72, 76-78, 82-83.

This is cosmetic. Since `SECURITY_REVIEW.md` is a point-in-time audit, updating line numbers is low priority but would improve accuracy.

---

## Suggestions

### 1. The `# __enable_bash_strict_mode__` marker does not actually enable strict mode

No `set -euo pipefail` is present. This is pre-existing (same in original `setup.sh`), so not a regression. But if the marker is meant to be actionable, consider actually adding `set -euo pipefail` in a follow-up. Note: `set -e` would interact with the `grep -q` verification commands on lines 64-65 (they can return non-zero), so those would need adjustment.

---

## What Was Verified

- `bash -n setup_on_fedora.sh` -- syntax OK
- All tracked files checked for stale `setup.sh` references -- none found outside `.ai_out/`
- Existing permissions logic (steps 2-7 in `main()`) is byte-for-byte identical to the original
- `__enable_bash_strict_mode__` anchor point preserved
- Documentation references updated in `README.md`, `VM_SETUP_CLAUDE_CODE.md`, `SECURITY_REVIEW.md`
- No functionality removed

---

## Signal

**Ready for convergence.** The IMPORTANT items above are acknowledgement-level, not blocking.
