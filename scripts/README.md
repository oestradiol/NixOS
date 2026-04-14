# Scripts

Helper scripts only. They do not replace the document pipeline.

All scripts use `set -euo pipefail`. Review them before running.

## Current role split
- install preparation only → `rebuild-install.sh`
- staged Secure Boot helper only → `post-install-secureboot-tpm.sh`
- static repo/audit handoff only → `audit-tutorial.sh`

## Inventory

| Script | Purpose | When to Run | Risk |
|---|---|---|---|
| `rebuild-install.sh` | Create the target GPT + LUKS2 + Btrfs + tmpfs-root mount layout under `/mnt` | Before first install, from the installer | **Destructive** |
| `post-install-secureboot-tpm.sh` | Stage Secure Boot key creation/enrollment and print the remaining TPM step | Only after the first stable encrypted baseline already exists | Medium |
| `audit-tutorial.sh` | Read-only static repo checks plus a runtime-check handoff | Any time | Low |

## What scripts do not do
- they do not replace `docs/PRE-INSTALL.md`
- they do not replace `docs/INSTALL-GUIDE.md`
- they do not replace `docs/TEST-PLAN.md`
- they do not make staged features baseline-ready automatically
