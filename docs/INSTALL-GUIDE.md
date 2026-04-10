# INSTALL GUIDE

This is the concrete install path for the uploaded hardware:
- Ryzen 5 3600
- NVIDIA GTX 1060
- one main NVMe (`/dev/nvme0n1`)
- current Windows/old NixOS state will be deleted
- SATA disk is left untouched and unused

## Phase 0 — backup and firmware
1. Confirm backups are complete.
2. Boot a recent official NixOS minimal installer in UEFI mode. The flake itself is pinned to `nixos-unstable`, so the installer only needs to be recent enough to boot the hardware.
3. In firmware:
   - keep Secure Boot disabled for the first install
   - keep TPM enabled
   - set an admin/UEFI password if available

## Phase 1 — partition and encrypt
Use `scripts/install-nvme-rebuild.sh` or run equivalent commands manually.

Target GPT layout on `/dev/nvme0n1`:
- `NIXBOOT` EFI FAT32, 512 MiB
- `NIXCRYPT` LUKS2, rest of disk

Inside `cryptroot` Btrfs create:
- `@nix`
- `@persist`
- `@log`
- `@swap` (then `chattr +C /mnt/swap` — nocow required for Btrfs swap)
- `@home-daily`
- `@home-paranoid`

## Phase 2 — mount target
- root: tmpfs on `/mnt`
- mount subvolumes to `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, `/mnt/home/player`, `/mnt/home/ghost`
- mount EFI to `/mnt/boot`

## Phase 3 — install repo
1. Copy this repository to `/mnt/etc/nixos`.
2. Ensure `hosts/nixos/hardware-target.nix` is active.
3. Run:
   - `nixos-install --flake /mnt/etc/nixos#nixos`
4. Reboot.

## Phase 4 — first boot behavior
- boot default system (daily)
- log in as `player`
- set real passwords for `player` and `ghost`
- confirm Plasma 6 Wayland works
- confirm NVIDIA stack works
- confirm Steam/VR not yet re-enabled by user data migration, only by config

## Phase 5 — only after first clean boot
Follow `docs/POST-INSTALL.md` for:
- Secure Boot / Lanzaboote
- TPM2 enrollment
- Mullvad setup
- agenix secrets creation

## Persistence map

### Btrfs subvolumes
- `@nix` → `/nix`
- `@persist` → `/persist`
- `@log` → `/var/log`
- `@home-daily` → `/home/player`
- `@home-paranoid` → `/home/ghost`

### tmpfs root
`/` is tmpfs — everything not allowlisted is discarded on reboot.

### System persistence allowlist
`/var/lib/nixos`, `/var/lib/systemd`, `/etc/NetworkManager/system-connections`, `/var/lib/bluetooth`, `/var/lib/flatpak`, `/var/lib/mullvad-vpn`, `/etc/mullvad-vpn`, SSH host keys, `/etc/machine-id`

### Daily user persistence
Data, Steam state, Vesktop/Discord/Signal state, KeePassXC config, keyrings, GPG, SSH, shell history

### Paranoid user persistence
Downloads, Documents, Signal state, KeePassXC config, GPG, SSH, shell history

### Explicitly non-persistent
Browser session junk, arbitrary root filesystem writes, most caches and temp files

## Notes
- Boot specialisations are chosen at boot.
- SDDM user choice is separate from boot specialisation choice.
- Default boot is daily. The paranoid specialisation is a separate boot entry.
