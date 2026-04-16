# Scripts

Helper scripts only. They do not replace the document pipeline.

All scripts use `set -euo pipefail`. Review them before running.

## Current role split
- guided first-install orchestrator → `rebuild-install.sh`
- staged Secure Boot helper only → `post-install-secureboot-tpm.sh`
- static repo/audit handoff only → `audit-tutorial.sh`

## Inventory

| Script | Purpose | When to Run | Risk |
|---|---|---|---|
| `rebuild-install.sh` | Guided installer for this repo: partition, encrypt, create subvolumes, mount, copy repo, generate hardware scan, run `nixos-install`, and prompt for user passwords | Before first install, from the installer ISO | **Destructive** |
| `post-install-secureboot-tpm.sh` | Stage Secure Boot key creation/enrollment and print the remaining TPM step | Only after the first stable encrypted baseline already exists | Medium |
| `audit-tutorial.sh` | Read-only static repo checks plus a runtime-check handoff | Any time | Low |

## What scripts do not do
- they do not replace `docs/pipeline/INSTALL-GUIDE.md`
- they still expect you to review the updated `hardware-target.nix`, secret-file paths, and runtime test-plan surfaces before treating the machine as stable
- they do not replace `docs/pipeline/TEST-PLAN.md`
- they do not make staged features baseline-ready automatically

## Feature reference
- for a complete inventory of what this repo contains and how the profiles differ, see `docs/maps/FEATURES.md`
