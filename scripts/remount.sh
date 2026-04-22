#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

MNT="/mnt"

umount -R "$MNT" >/dev/null 2>&1 || true
swapoff -a >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true

cryptsetup open /dev/nvme0n1p5 cryptroot

mount -t tmpfs none "$MNT" -o mode=755,size=4G
# These paths match the default template's user naming convention.
# Forkers should edit this script to match their template's user names.
mkdir -p "$MNT"/{boot,nix,persist,var/log,home/daily-user,persist/home/paranoid-user,swap,etc}
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/nix"
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist"
chmod 700 "$MNT/persist"
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/var/log"
mount -o subvol=@home-daily,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/home/daily-user"
mount -o subvol=@home-paranoid,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist/home/paranoid-user"
chmod 700 "$MNT/persist/home/paranoid-user"
mount -o subvol=@swap,noatime,nodatacow /dev/mapper/cryptroot "$MNT/swap"
mount -t vfat -o fmask=0077,dmask=0077 /dev/nvme0n1p1 "$MNT/boot"

echo "Testing swapfile activation..."
swapon "$MNT/swap/swapfile" && swapoff "$MNT/swap/swapfile" && echo "Swapfile test: OK" || {
  echo "ERROR: Swapfile failed to activate. Check Btrfs configuration."
  exit 1
}
