# INSTALL GUIDE

## Prerequisites

Confirm the following before starting:

### 1. Target model
- one installation
- default profile = `paranoid`
- boot specialization = `daily`
- `player` = normal daily account
- `ghost` = hardened workspace account

### 2. Storage plan
You are about to install the repo's expected layout:
- EFI partition labeled `NIXBOOT`
- LUKS2 partition labeled `NIXCRYPT`
- Btrfs subvolumes for `@nix`, `@persist`, `@log`, `@swap`, `@home-daily`, `@home-paranoid`
- tmpfs root

### 3. Secrets and local data
Before install or immediately after first boot, know where these will live:
- user passwords are set declaratively via hashedPasswordFile pointing to /persist/secrets/{player,ghost}-password.hash
- the install script will prompt for passwords and write the hashed files
- any agenix-managed secret files you will actually use
- Mullvad app credentials/workflow if you use the app path immediately
- if you later enable the staged self-owned WireGuard path: private key, optional preshared key, tunnel address, server public key, and pinned literal endpoint `IP:port`

### 4. Current baseline profile split
Current repo state:
- daily: `sandbox.apps = true`, `sandbox.browsers = false`, `sandbox.vms = false`, `wireguardMullvad.enable = false`
- paranoid: `sandbox.apps = false`, `sandbox.browsers = true`, `sandbox.vms = true`, `wireguardMullvad.enable = false`
- both profiles currently use Mullvad app mode by default

Browser split:
- daily Firefox = enterprise-policy-managed normal Firefox
- paranoid Firefox = `safe-firefox` wrapper with vendored arkenfox baseline + repo overrides
- Tor Browser / Mullvad Browser = upstream browser model + local wrapper containment only

### 5. Staged features (not baseline yet)
These are not part of the first stable install target:
- Secure Boot rollout
- TPM-bound unlock rollout
- self-owned WireGuard host path
- repo custom audit rules
- custom AppArmor profile library

### 6. Red flags before starting
Stop and fix these before running the install script:
- you have not backed up the target disk
- you are not willing to wipe the target disk completely
- you have not decided how user passwords will be set before first real boot
- you intend to enable the staged self-owned WireGuard path soon but do not have a pinned literal endpoint `IP:port`
- you are planning to treat post-stability items as blocking for the first machine-usable baseline

## Installation steps

### 1. Prepare the disk
- boot the NixOS installer
- run `scripts/rebuild-install.sh` from the installer ISO
- it will prompt for destructive confirmation, the LUKS passphrase, run the filesystem setup, copy the repo into `/mnt/etc/nixos`, generate a hardware scan, optionally run `nix flake check`, run `nixos-install`, and offer to set `player`/`ghost` passwords in the installed system
- confirm `/mnt`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, and `/mnt/boot` are mounted as expected if you stop before install

## 2. Review the staged repo
- `rebuild-install.sh` copies the repo to `/mnt/etc/nixos` automatically
- it updates `/mnt/etc/nixos/templates/default/hosts/nixos/hardware-target.nix` from the installer scan for review
- place or prepare host-local secrets outside git
- review the generated files before treating the install as final
- do not overwrite repo-owned layout, impermanence, or profile policy wholesale
- for a complete inventory of what this repo contains and how the profiles differ, see `docs/maps/FEATURES.md`

## 3. Install the system
- if you let the script continue, it will run `nixos-install --flake /mnt/etc/nixos#nixos --no-root-passwd` for you
- it can then immediately prompt for `player` and `ghost` passwords through `nixos-enter`
- reboot
- at the boot menu, choose the `daily` specialization first for the first validation cycle

## 4. First boot: canonical edits only
Do not add a separate local override layer for basic identity. Make the first boot edits in the canonical tracked files.

Required first-boot edits:
- set the hostname in `templates/default/hosts/nixos/default.nix` by changing `networking.hostName`
- set git identity in the canonical shared Home Manager path: `modules/home/common.nix`
- only move git identity into per-user files later if you intentionally want different identities per account

Suggested commands after logging into the `daily` specialization:
- `sudoedit /etc/nixos/templates/default/hosts/nixos/default.nix`
- `sudoedit /etc/nixos/modules/home/common.nix`
- `cd /etc/nixos && sudo nixos-rebuild switch --flake .#nixos --specialisation daily`

The first boot goal is not “finish every hardening feature.” The first boot goal is:
- make daily reachable
- make daily recoverable
- make daily good enough to continue iteration safely

## 5. After first boot
- place any required secret files where the config expects them
- rebuild if secret paths changed
- do daily-first validation from `docs/pipeline/TEST-PLAN.md`
- only move to the paranoid validation section after daily is already usable
