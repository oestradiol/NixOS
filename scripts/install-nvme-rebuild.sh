#!/usr/bin/env bash
set -euo pipefail

DISK="${1:-/dev/nvme0n1}"
MNT="/mnt"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if [[ ! -b "$DISK" ]]; then
  echo "Target disk not found: $DISK" >&2
  exit 1
fi

if findmnt -rn -S "$DISK" >/dev/null 2>&1; then
  echo "Refusing to continue: $DISK already has mounted filesystems." >&2
  lsblk "$DISK"
  exit 1
fi

mounted_parts=$(lsblk -nrpo NAME "$DISK" | tail -n +2 | while read -r part; do
  findmnt -rn -S "$part" >/dev/null 2>&1 && echo "$part"
done)
if [[ -n "${mounted_parts:-}" ]]; then
  echo "Refusing to continue: one or more partitions on $DISK are mounted:" >&2
  printf '%s
' "$mounted_parts" >&2
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK"
  exit 1
fi

echo "About to DESTROY all data on: $DISK"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK"
read -r -p "Type WIPE to continue: " CONFIRM
[[ "$CONFIRM" == "WIPE" ]] || { echo "Aborted."; exit 1; }

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
mount -o subvol=@swap,noatime,nodatacow /dev/mapper/cryptroot "$MNT/swap"

btrfs filesystem mkswapfile --size 8g --uuid clear "$MNT/swap/swapfile"

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
echo
echo "hardware-target.nix derives the /home/ghost tmpfs uid/gid from the configured ghost user."
echo "Verify users.users.ghost.uid and group match your intended account before nixos-install."
echo
echo "Next: copy this repo to $MNT/etc/nixos"
echo "Then refresh the host hardware scan into /mnt/etc/nixos/hosts/nixos/hardware-install-generated.nix"
echo "Example: nixos-generate-config --root $MNT --show-hardware-config > $MNT/etc/nixos/hosts/nixos/hardware-install-generated.nix"
echo "Merge hardware detection deltas from hardware-install-generated.nix into hosts/nixos/hardware-target.nix."
echo "Do not overwrite repo-owned layout, impermanence, or profile policy in hardware-target.nix wholesale."
echo "Then run nixos-install --flake /mnt/etc/nixos#nixos"
