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
The installer supports one storage topology in this pass:
- one EFI partition
- one LUKS2 root partition
- Btrfs subvolumes under that encrypted root
- tmpfs `/`

If you keep the framework defaults, the expected identifiers are:
- EFI label `NIXBOOT`
- encrypted root partlabel `NIXCRYPT`
- Btrfs subvolumes `@nix`, `@persist`, `@log`, optional `@swap`

Per-user home subvolumes are derived from `myOS.users.*`, not hardcoded
in the script.

### 3. Secrets and local data
Before install or immediately after first boot, know where these will live:
- user passwords are set declaratively via any discovered `hashedPasswordFile`
  paths in the selected config and its specialisations
- the install script will prompt only for those discovered password-hash
  targets and write the hashed files under the staged root
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
- run `scripts/rebuild-install.sh` from the installer ISO or from the
  framework/downstream checkout you want to install
- the script will ask for:
  - target flake path or URL
  - framework template path
  - `nixosConfiguration` attribute
  - EFI partition device
  - encrypted root partition device
- it then evaluates the selected config, derives storage + password-hash
  targets from that config, formats the selected partitions, stages the
  flake into `/mnt/etc/nixos`, generates `hardware-target.nix`, optionally
  runs `nix flake check`, and runs `nixos-install`
- confirm `/mnt`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, and `/mnt/boot`
  are mounted as expected if you stop before install

## 2. Review the staged repo
- `rebuild-install.sh` stages the selected flake source into `/mnt/etc/nixos`
- if the flake consumes this framework as an input, the pinned framework
  source is vendored into the staged tree so the install remains self-contained
- it writes the generated hardware file at the template-relative
  `hardware-target.nix` path before install
- place or prepare host-local secrets outside git
- review the generated files before treating the install as final
- do not overwrite repo-owned storage policy, impermanence, or profile policy wholesale
- for a complete inventory of what this repo contains and how the profiles differ, see `docs/maps/FEATURES.md`

## 3. Install the system
- if you let the script continue, it will run
  `nixos-install --flake <staged-flake>#<selected-config> --no-root-passwd`
  for you
- any declarative user passwords are written before `nixos-install`, based
  on the `hashedPasswordFile` paths discovered from the evaluated config
- reboot
- for the reference template, choose the `daily` specialization first for
  the first validation cycle

## 4. First boot: canonical edits only
For the reference `templates/default` machine, keep the first boot focused
on verification and only touch the sanctioned override points.

Required first-boot edits:
- review `templates/default/hosts/nixos/hardware-target.nix`
- set hostname or storage-device overrides in `templates/default/hosts/nixos/local.nix`
- set identity in `templates/default/accounts/*.local.nix`

Suggested commands after logging into the `daily` specialization of the
reference template:
- `sudoedit /etc/nixos/templates/default/hosts/nixos/default.nix`
- `sudoedit /etc/nixos/templates/default/hosts/nixos/local.nix`
- `sudoedit /etc/nixos/templates/default/accounts/player.local.nix`
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
