# Implementation Plan: simplify-setup

## Goal
Rename setup.sh to setup_on_fedora.sh, add install_if_missing function for auto-installing dependencies, update all docs.

## Steps
1. [x] Rename setup.sh -> setup_on_fedora.sh via git mv
2. [x] Fix double shebang (keep #!/usr/bin/env bash only)
3. [x] Add install_if_missing function (detects dnf/apt/apt-get/brew)
4. [x] Use install_if_missing for evemu (check evemu-event) and gnome-screenshot
5. [x] Keep existing permissions logic (steps 2-7) as-is
6. [x] Update VM_SETUP_CLAUDE_CODE.md (all references, simplify Section 1)
7. [x] Update README.md (all references)
8. [x] Update SECURITY_REVIEW.md (all references)
9. [x] Verify no remaining setup.sh references in tracked files

## State: COMPLETE
All steps done. Script passes bash -n syntax check.
