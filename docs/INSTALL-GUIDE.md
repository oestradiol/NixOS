# INSTALL GUIDE

Only installation steps.

## 1. Prepare the disk
- boot the NixOS installer
- run `scripts/rebuild-install.sh` or do the exact equivalent manually
- confirm `/mnt`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, and `/mnt/boot` are mounted as expected

## 2. Place the repo
- copy this repo to `/mnt/etc/nixos`
- place or prepare host-local secrets outside git
- generate a fresh hardware scan into a scratch file such as `/mnt/etc/nixos/hosts/nixos/hardware-install-generated.nix`
- reconcile hardware-detection deltas into `hosts/nixos/hardware-target.nix`
- do not overwrite repo-owned layout, impermanence, or profile policy wholesale

## 3. Install the system
- run `nixos-install --flake /mnt/etc/nixos#nixos`
- reboot
- at the boot menu, choose the `daily` specialization first for the first validation cycle

## 4. First-boot rule
The first boot goal is not “finish every hardening feature.”
The first boot goal is:
- make daily reachable
- make daily recoverable
- make daily good enough to continue iteration safely

## 5. After first boot
- place any required secret files where the config expects them
- rebuild if host-local secret paths changed
- do daily-first validation from `docs/TEST-PLAN.md`
- only move to the paranoid validation section after daily is already usable
