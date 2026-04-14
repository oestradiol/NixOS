# INSTALL GUIDE

Only installation steps.

## 1. Prepare the disk
- boot the NixOS installer
- run `scripts/rebuild-install.sh` or perform the equivalent manual layout
- confirm `/mnt`, `/mnt/persist`, and `/mnt/boot` are mounted as expected

## 2. Place the repo
- copy this repo to `/mnt/etc/nixos`
- place or prepare the host-specific secrets out of git
- generate a fresh hardware scan into `hosts/nixos/hardware-install-generated.nix`
- reconcile `hardware-install-generated.nix` into `hosts/nixos/hardware-target.nix`
- copy hardware-detection deltas only; do not overwrite repo-owned layout, impermanence, or profile policy wholesale

## 3. Install daily first
- run `nixos-install --flake /mnt/etc/nixos#nixos`
- reboot into the daily profile first
- treat the first boot goal as: make daily reachable, recoverable, and operable before spending time on paranoid

## 4. After first boot
- place the required secret files where the config expects them
- rebuild if any host-local secret paths changed
- validate only the daily-critical items first so you can reach a stable working base quickly

## 5. Only then move to paranoid
- do not boot paranoid until daily is stable enough to recover from failures and continue iteration
- once daily is operable, continue with the daily-first sections of `docs/TEST-PLAN.md`
- only after those pass should you continue with the paranoid minimum-state section
