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
mount -o subvol=@swap,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/swap"

# Create Btrfs swapfile (8GB) - required for the swapDevices config in base-desktop.nix
# Using traditional fallocate + mkswap approach on Btrfs (COW disabled on @swap via chattr +C)
fallocate -l 8G "$MNT/swap/swapfile"
chmod 600 "$MNT/swap/swapfile"
mkswap "$MNT/swap/swapfile"

mount "${DISK}p1" "$MNT/boot"

echo "Mounts ready at $MNT"
echo "Swapfile created: /swap/swapfile (8GB)"
echo "@home-paranoid -> /mnt/persist/home/ghost (runtime: /persist/home/ghost)"
echo "Now copy this repo to $MNT/etc/nixos and run nixos-install --flake /mnt/etc/nixos#nixos"
