# Scripts

Helper scripts for installation, static audit, and staged boot hardening.

All scripts use `set -euo pipefail`. Review them before running.

## Inventory

| Script | Purpose | When to Run | Risk |
|---|---|---|---|
| `install-nvme-rebuild.sh` | Create the target GPT + LUKS2 + Btrfs + tmpfs-root mount layout under `/mnt` | Before first install, from the installer | **Destructive** |
| `post-install-secureboot-tpm.sh` | Stage Secure Boot key creation/enrollment and print the remaining TPM step | Only after the first stable encrypted daily boot | Medium |
| `audit-tutorial.sh` | Read-only static repo checks plus a runtime checklist handoff | Any time | Low |

## `install-nvme-rebuild.sh`

What it is responsible for:
- wipe the selected target disk
- create the repo's expected partition labels (`NIXBOOT`, `NIXCRYPT`)
- create the expected Btrfs subvolumes
- mount the expected install layout under `/mnt`
- create and test the Btrfs-native swapfile expected by `modules/desktop/base.nix`
- remind you about the `ghost` UID/GID dependency used by `hosts/nixos/hardware-target.nix`
- print the hardware-config refresh and reconciliation step required before `nixos-install`

What it is **not** responsible for:
- copying the repo into `/mnt/etc/nixos`
- generating host secrets
- running `nixos-install`
- validating post-boot functionality

## `post-install-secureboot-tpm.sh`

What it is responsible for:
- creating Secure Boot keys with `sbctl`
- enrolling them with Microsoft CA support
- printing the remaining firmware and TPM enrollment steps

What it is **not** responsible for:
- flipping repo options for you
- enabling Secure Boot in firmware
- performing TPM enrollment automatically
- validating the resulting boot chain

## `audit-tutorial.sh`

What it is responsible for:
- `nix flake show`
- `nix flake check`
- verifying canonical docs exist
- grepping the main persistence / Secure Boot / WireGuard / browser / audit / AppArmor / scanner / Flatpak surfaces
- printing the runtime checks that belong in `docs/TEST-PLAN.md`

What it is **not** responsible for:
- mutating system state
- proving runtime correctness
- replacing the staged checks in `docs/TEST-PLAN.md`
- replacing the deferred work tracked in `docs/POST-STABILITY.md`
