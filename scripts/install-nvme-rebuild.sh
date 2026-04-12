#!/usr/bin/env bash
set -euo pipefail

DISK="${1:-/dev/nvme0n1}"
MNT="/mnt"

# WARNING: destructive. This is the target plan for the NVMe only.
sgdisk --zap-all "$DISK"
partprobe "$DISK"

sgdisk -n 1:1MiB:+512MiB -t 1:EF00 -c 1:NIXBOOT "$DISK"
sgdisk -n 2:0:0      -t 2:8309 -c 2:NIXCRYPT "$DISK"
partprobe "$DISK"

mkfs.fat -F 32 -n NIXBOOT "${DISK}p1"
cryptsetup luksFormat --type luks2 "${DISK}p2"
cryptsetup open "${DISK}p2" cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot "$MNT"
btrfs subvolume create "$MNT/@nix"
btrfs subvolume create "$MNT/@persist"
btrfs subvolume create "$MNT/@log"
btrfs subvolume create "$MNT/@swap"
chattr +C "$MNT/@swap"
btrfs subvolume create "$MNT/@home-daily"
btrfs subvolume create "$MNT/@home-paranoid"
umount "$MNT"

mount -t tmpfs none "$MNT" -o mode=755,size=4G
mkdir -p "$MNT"/{boot,nix,persist,var/log,home/player,persist/home/ghost,swap}
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/nix"
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist"
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/var/log"
mount -o subvol=@home-daily,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/home/player"
mount -o subvol=@home-paranoid,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist/home/ghost"
# Note: NO compression on swap subvolume - swapfiles must be NOCOW and non-compressed
mount -o subvol=@swap,noatime,nodatacow /dev/mapper/cryptroot "$MNT/swap"

# Create Btrfs swapfile (8GB) - required for the swapDevices config in base-desktop.nix
# Requirements:
# - COW disabled on @swap subvolume via chattr +C (done above)
# - mount with nodatacow (done above)
# - fallocate (not dd) for preallocated extents
# - swapfile cannot be snapshotted while active
fallocate -l 8G "$MNT/swap/swapfile"
chmod 600 "$MNT/swap/swapfile"
mkswap "$MNT/swap/swapfile"

# Test swapon in chroot to verify swapfile works before reboot
# This catches Btrfs swapfile configuration errors early
echo "Testing swapfile activation..."
swapon "$MNT/swap/swapfile" && swapoff "$MNT/swap/swapfile" && echo "Swapfile test: OK" || {
    echo "ERROR: Swapfile failed to activate. Check Btrfs configuration."
    exit 1
}

mount "${DISK}p1" "$MNT/boot"

echo "Mounts ready at $MNT"
echo "Swapfile created: /swap/swapfile (8GB)"
echo "Swapfile tested: swapon/swapoff verified successfully"
echo "WARNING: Do not snapshot @swap subvolume while swapfile is active"
echo "@home-paranoid -> /mnt/persist/home/ghost (runtime: /persist/home/ghost)"
echo ""
echo "WARNING: hardware-target.nix has uid=1001/gid=100 for /home/ghost tmpfs mount."
echo "Verify these match your actual ghost user UID/GID before running nixos-install."
echo "Mismatch will cause permission issues on paranoid profile."
echo ""
echo "Now copy this repo to $MNT/etc/nixos and run nixos-install --flake /mnt/etc/nixos#nixos"
