# INSTALL GUIDE

Only installation steps.

## 1. Prepare the disk
- boot the NixOS installer
- run `scripts/rebuild-install.sh` from the installer ISO
- it will prompt for destructive confirmation, the LUKS passphrase, run the filesystem setup, copy the repo into `/mnt/etc/nixos`, generate a hardware scan, optionally run `nix flake check`, run `nixos-install`, and offer to set `player`/`ghost` passwords in the installed system
- confirm `/mnt`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, and `/mnt/boot` are mounted as expected if you stop before install

## 2. Review the staged repo
- `rebuild-install.sh` copies the repo to `/mnt/etc/nixos` automatically
- it updates `/mnt/etc/nixos/hosts/nixos/hardware-target.nix` from the installer scan for review
- place or prepare host-local secrets outside git
- review the generated hardware-target file, expected secret-file paths, and staged repo state before treating the install as final
- do not overwrite repo-owned layout, impermanence, or profile policy wholesale
- for a complete inventory of what this repo contains and how the profiles differ, see `docs/FEATURES.md`

## 3. Install the system
- if you let the script continue, it will run `nixos-install --flake /mnt/etc/nixos#nixos --no-root-passwd` for you
- it can then immediately prompt for `player` and `ghost` passwords through `nixos-enter`
- reboot
- at the boot menu, choose the `daily` specialization first for the first validation cycle

## 4. First boot: canonical edits only
Do not add a separate local override layer for basic identity. Make the first boot edits in the canonical tracked files.

Required first-boot edits:
- set the hostname in `hosts/nixos/default.nix` by changing `networking.hostName`
- set git identity in `modules/home/common.nix` or another single shared Home Manager git settings path you intentionally choose to own

Suggested commands after logging into the `daily` specialization:
- `sudoedit /etc/nixos/hosts/nixos/default.nix`
- `sudoedit /etc/nixos/modules/home/common.nix`
- `cd /etc/nixos && sudo nixos-rebuild switch --flake .#nixos --specialisation daily`

The first boot goal is not “finish every hardening feature.” The first boot goal is:
- make daily reachable
- make daily recoverable
- make daily good enough to continue iteration safely

## 5. After first boot
- place any required secret files where the config expects them
- rebuild if secret paths changed
- do daily-first validation from `docs/TEST-PLAN.md`
- only move to the paranoid validation section after daily is already usable
