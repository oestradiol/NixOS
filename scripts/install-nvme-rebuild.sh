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
btrfs subvolume create "$MNT/@home-daily"
btrfs subvolume create "$MNT/@home-paranoid"
umount "$MNT"

mount -t tmpfs none "$MNT" -o mode=755,size=4G
mkdir -p "$MNT"/{boot,nix,persist,var/log,home/player,home/ghost}
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/nix"
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist"
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/var/log"
mount -o subvol=@home-daily,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/home/player"
mount -o subvol=@home-paranoid,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/home/ghost"
mount "${DISK}p1" "$MNT/boot"

echo "Mounts ready at $MNT"
echo "Now copy this repo to $MNT/etc/nixos and run nixos-install --flake /mnt/etc/nixos#nixos"
