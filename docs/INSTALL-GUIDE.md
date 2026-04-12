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
- mount subvolumes to `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, `/mnt/home/player`, `/mnt/persist/home/ghost`
- mount EFI to `/mnt/boot`

**Note**: `@home-paranoid` mounts to `/mnt/persist/home/ghost` (runtime: `/persist/home/ghost`), not `/mnt/home/ghost`

**CRITICAL**: Verify `hardware-target.nix` tmpfs mount options derive from `config.users.users."ghost"` UID/GID. Mismatch causes permission failures on paranoid boot.

**How to verify** (run on existing system or check `modules/core/users.nix`):
```bash
# Check ghost user UID/GID in the new system
grep -A10 'users.users."ghost"' modules/core/users.nix
# Should show: uid = 1001; and group = "users";

# Verify hardware-target.nix uses config derivation:
grep -A5 'fileSystems."/home/ghost"' hosts/nixos/hardware-target.nix
# Should show: uid=\${toString config.users.users."ghost".uid}

# If already have a ghost user, check current values:
id ghost  # Output: uid=1001(ghost) gid=100(users) groups=100(users)
```

## Phase 3 — install repo
1. Copy this repository to `/mnt/etc/nixos`.
2. Ensure `hosts/nixos/hardware-target.nix` is active.
3. Run:
   - `nixos-install --flake /mnt/etc/nixos#nixos`
4. Reboot.

## Phase 4 — password setup (CRITICAL: before first boot)

**IMPORTANT**: Users without a password cannot log in via password-based mechanisms (TTY, SDDM).
Set passwords BEFORE rebooting, while still in the installer chroot:

```bash
# Enter the chroot environment
nixos-enter --root /mnt

# Set initial passwords
passwd player
passwd ghost

# Exit chroot
exit
```

Alternative: Set `users.users.player.initialPassword = "temp"` in config before install.

## Phase 5 — first boot verification
- boot default system (daily)
- log in as `player` with the password you set
- confirm Plasma 6 Wayland works
- confirm NVIDIA stack works
- confirm Steam/VR not yet re-enabled by user data migration, only by config

**If first boot fails**: See [`RECOVERY.md`](./RECOVERY.md) "If the new system does not boot" section.

## Phase 6 — only after first clean boot
Follow [`TEST-PLAN.md`](./TEST-PLAN.md) for immediate runtime verification.

Then follow [`POST-STABILITY.md`](./POST-STABILITY.md) for:
- Secure Boot / Lanzaboote
- TPM2 enrollment
- VPN setup (daily: Mullvad app, paranoid: WireGuard - see Section 15 of PRE-INSTALL.md)
- agenix secrets creation

**If issues occur during Phase 6**: See [`RECOVERY.md`](./RECOVERY.md) for troubleshooting.

## Persistence map

### Btrfs subvolumes
- `@nix` → `/nix` (fully persistent)
- `@persist` → `/persist` (fully persistent)
- `@log` → `/var/log` (fully persistent)
- `@home-daily` → `/home/player` (fully persistent subvolume)
- `@home-paranoid` → `/persist/home/ghost` (persistent storage for selective impermanence)

### tmpfs root
`/` is tmpfs — everything not allowlisted is discarded on reboot.

### System persistence allowlist
`/var/lib/nixos`, `/var/lib/systemd`, `/etc/NetworkManager/system-connections`, `/var/lib/flatpak`, SSH host keys, `/etc/{passwd,shadow,group,gshadow,subuid,subgid}`

**Daily-only persistence** (not persisted on paranoid):
- `/var/lib/bluetooth` — paired controllers (daily gaming use)
- `/var/lib/mullvad-vpn`, `/etc/mullvad-vpn` — Mullvad app state (daily VPN mode)

**Note**: `/etc/machine-id` is **persisted on both profiles**:
- **daily**: systemd-generated unique stable ID (operational stability for D-Bus, Steam, network)
- **paranoid**: Whonix shared ID `b08dfa6083e7567a1921a715000001fb` (privacy: blends with all Whonix users)

Reference: https://github.com/Whonix/dist-base-files/blob/master/etc/machine-id

### User data persistence model (profile-dependent)

**Daily profile** (`/home/player`):
- Fully persistent Btrfs subvolume (`@home-daily`)
- All data survives reboot
- Impermanence allowlist manages dotfiles within persistent home

**Paranoid profile** (`/home/ghost`):
- **Selective impermanence**: tmpfs home + allowlist
- `/home/ghost` is tmpfs (wiped on boot)
- `@home-paranoid` mounted to `/persist/home/ghost` for persistence
- Only allowlisted items are bind-mounted into tmpfs home
- Malware/ransomware in home is wiped on reboot

**Persisted dotfiles (daily)**: Steam, Signal, Bitwarden (Flatpak), Vesktop, Spotify, Obsidian, Windsurf, VRCX, keyrings, GPG, SSH, shell history
**Persisted dotfiles (paranoid)**: Signal, KeePassXC, keyrings, GPG, SSH, shell history
- Firefox: Profiles persist via Btrfs subvolume (not impermanence allowlist)
- Sandboxed browsers (safe-*): Ephemeral profiles for isolation

### Explicitly non-persistent
Browser session junk, arbitrary root filesystem writes, most caches and temp files

## Notes
- Boot specialisations are chosen at boot.
- SDDM user choice is separate from boot specialisation choice (any user can log in on any boot spec).
- Default boot is daily. The paranoid specialisation is a separate boot entry.
