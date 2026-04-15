#!/usr/bin/env bash
set -euo pipefail

MNT="/mnt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

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

for cmd in lsblk findmnt sgdisk mkfs.fat cryptsetup mkfs.btrfs mount umount btrfs swapon swapoff nixos-generate-config nixos-install nixos-enter sed awk grep; do
  need_cmd "$cmd"
done

if [[ ! -f "$REPO_ROOT/flake.nix" || ! -d "$REPO_ROOT/hosts/nixos" ]]; then
  echo "Could not locate repo root from script path: $REPO_ROOT" >&2
  echo "Run this script from inside your repo checkout." >&2
  exit 1
fi

echo "Guided installer for this repo (dual-boot mode)"
echo "Repo root: $REPO_ROOT"
echo
echo "This script will only reformat /dev/nvme0n1p1 (EFI) and /dev/nvme0n1p5 (Linux)."
echo "All other partitions and disks will be preserved."
echo

# Hardcoded to use only nvme0n1p1 (EFI) and nvme0n1p5 (Linux)
# Preserves p2, p3, p4 and all other disks
DISK="/dev/nvme0n1"
BOOT_PART="${DISK}p1"
CRYPT_PART="${DISK}p5"

# Verify target partitions exist
if [[ ! -b "$BOOT_PART" ]]; then
  echo "ERROR: EFI partition not found: $BOOT_PART" >&2
  exit 1
fi
if [[ ! -b "$CRYPT_PART" ]]; then
  echo "ERROR: Linux partition not found: $CRYPT_PART" >&2
  exit 1
fi

# Verify target partitions are not mounted
if findmnt -rn -S "$BOOT_PART" >/dev/null 2>&1; then
  echo "ERROR: EFI partition is mounted: $BOOT_PART" >&2
  exit 1
fi
if findmnt -rn -S "$CRYPT_PART" >/dev/null 2>&1; then
  echo "ERROR: Linux partition is mounted: $CRYPT_PART" >&2
  exit 1
fi

echo
echo "Target configuration:"
echo "  EFI partition: $BOOT_PART (will be reformatted)"
echo "  LUKS partition: $CRYPT_PART (will be reformatted)"
echo "  Preserved: ${DISK}p2, ${DISK}p3, ${DISK}p4, /dev/sda, /dev/sdb"
echo
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK"
read -r -p "Type REFORMAT to continue: " CONFIRM
[[ "$CONFIRM" == "REFORMAT" ]] || { echo "Aborted."; exit 1; }

umount -R "$MNT" >/dev/null 2>&1 || true
swapoff -a >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true

# Set partition label for LUKS partition (required by fs-layout.nix)
sgdisk -c 5:NIXCRYPT "$DISK"

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
