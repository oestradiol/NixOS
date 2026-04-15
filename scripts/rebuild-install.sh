#!/usr/bin/env bash
set -euo pipefail

MNT="/mnt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DISK="${1:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

prompt_default() {
  local prompt="$1" default="$2" value
  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}


confirm_yes() {
  local prompt="$1" answer
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

for cmd in lsblk findmnt sgdisk partprobe mkfs.fat cryptsetup mkfs.btrfs mount umount btrfs swapon swapoff nixos-generate-config nixos-install nixos-enter sed awk grep; do
  need_cmd "$cmd"
done

if [[ ! -f "$REPO_ROOT/flake.nix" || ! -d "$REPO_ROOT/hosts/nixos" ]]; then
  echo "Could not locate repo root from script path: $REPO_ROOT" >&2
  echo "Run this script from inside your repo checkout." >&2
  exit 1
fi

echo "Guided installer for this repo"
echo "Repo root: $REPO_ROOT"
echo

if [[ -z "$DISK" ]]; then
  echo "Available disks:"
  lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4=="disk" {print}'
  DISK="$(prompt_default 'Target disk to wipe and install to' '/dev/nvme0n1')"
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
  printf '%s\n' "$mounted_parts" >&2
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK"
  exit 1
fi

echo
echo "About to DESTROY all data on: $DISK"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK"
read -r -p "Type WIPE to continue: " CONFIRM
[[ "$CONFIRM" == "WIPE" ]] || { echo "Aborted."; exit 1; }

umount -R "$MNT" >/dev/null 2>&1 || true
swapoff -a >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true

sgdisk --zap-all "$DISK"
partprobe "$DISK"

sgdisk -n 1:1MiB:+512MiB -t 1:EF00 -c 1:NIXBOOT "$DISK"
sgdisk -n 2:0:0      -t 2:8309 -c 2:NIXCRYPT "$DISK"
partprobe "$DISK"

PARTSEP=""
case "$DISK" in
  *[0-9]) PARTSEP="p" ;;
esac
BOOT_PART="${DISK}${PARTSEP}1"
CRYPT_PART="${DISK}${PARTSEP}2"

mkfs.fat -F 32 -n NIXBOOT "$BOOT_PART"
echo
echo "You will now be prompted by cryptsetup for the LUKS passphrase."
cryptsetup luksFormat --type luks2 "$CRYPT_PART"
cryptsetup open "$CRYPT_PART" cryptroot
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
mkdir -p "$MNT"/{boot,nix,persist,var/log,home/player,persist/home/ghost,swap,etc}
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

mount "$BOOT_PART" "$MNT/boot"

TARGET_REPO="$MNT/etc/nixos"
rm -rf "$TARGET_REPO"
mkdir -p "$MNT/etc"
cp -a "$REPO_ROOT" "$TARGET_REPO"
rm -rf "$TARGET_REPO/.git" "$TARGET_REPO/result" 2>/dev/null || true


nixos-generate-config --root "$MNT"
if [[ -f "$MNT/etc/nixos/hardware-configuration.nix" ]]; then
  mv "$MNT/etc/nixos/hardware-configuration.nix" "$TARGET_REPO/hosts/nixos/hardware-target.nix"
fi

echo
echo "Generated hardware scan saved to: $TARGET_REPO/hosts/nixos/hardware-target.nix"
echo

if confirm_yes "Run 'nix flake check' on the copied repo before install?"; then
  (cd "$TARGET_REPO" && nix flake check)
fi

echo
echo "Mounts ready at $MNT"
findmnt -R "$MNT"
echo
echo "Planned install command: nixos-install --flake $TARGET_REPO#nixos --no-root-passwd"
confirm_yes "Proceed with nixos-install now?" || { echo "Stopping before nixos-install. Repo is staged at $TARGET_REPO"; exit 0; }

nixos-install --flake "$TARGET_REPO#nixos" --no-root-passwd

echo
echo "Base install complete. Next: set user passwords inside the installed system."
if confirm_yes "Set password for player now?"; then
  nixos-enter --root "$MNT" -c 'passwd player'
fi
if confirm_yes "Set password for ghost now?"; then
  nixos-enter --root "$MNT" -c 'passwd ghost'
fi

echo
cat <<'EOF'
Install staging complete.

Before rebooting, review:
- /mnt/etc/nixos/hosts/nixos/hardware-target.nix
- /mnt/etc/nixos/docs/pipeline/INSTALL-GUIDE.md
- /mnt/etc/nixos/docs/pipeline/TEST-PLAN.md

After reboot:
1. Choose the daily specialization first.
2. Follow the first-boot edits in docs/pipeline/INSTALL-GUIDE.md (hostname and git identity in canonical files).
3. Run the daily-first checks in docs/pipeline/TEST-PLAN.md.
4. Only after daily is good, continue with paranoid validation.
EOF
