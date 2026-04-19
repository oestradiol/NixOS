#!/usr/bin/env bash
# Guided installer for NixOS hardened workstation.
# Destroys entire target disk and creates fresh GPT partition table with EFI + LUKS partitions.
#
# Usage:
#   From inside a local checkout:
#     sudo ./scripts/rebuild-install.sh
#
#   Standalone via curl (clones the repo first):
#     curl -fsSL https://raw.githubusercontent.com/oestradiol/NixOS/main/scripts/rebuild-install.sh | sudo bash
set -euo pipefail

REPO_URL="https://github.com/oestradiol/NixOS.git"
REPO_BRANCH="main"

# ── Bootstrap: clone repo if running from stdin / outside the repo ─────
# When piped via curl, BASH_SOURCE[0] is empty and the repo isn't present.
# In that case, clone into a temp directory and re-exec from the checkout.
if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "bash" ]]; then
  # Running from stdin (curl pipe)
  CLONE_DIR="$(mktemp -d)"
  echo "Cloning $REPO_URL (branch: $REPO_BRANCH) into $CLONE_DIR ..."
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$CLONE_DIR"
  echo "Re-executing from cloned repo..."
  exec bash "$CLONE_DIR/scripts/rebuild-install.sh" "$@" < /dev/tty
fi

# ── Paths ───────────────────────────────────────────────────────────────
MNT="/mnt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CLEANUP_FILES=()

# ── Helpers ─────────────────────────────────────────────────────────────
phase() { printf '\n\033[1;36m══ %s ══\033[0m\n' "$*"; }
info()  { printf '\033[1;34m>> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
fail()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() { rm -f "${CLEANUP_FILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

confirm_yes() {
  local prompt="$1" answer
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

confirm_keyword() {
  local keyword="$1" prompt="$2" answer
  read -r -p "$prompt " answer
  [[ "$answer" == "$keyword" ]] || { echo "Aborted."; exit 1; }
}

write_password_hash() {
  local user="$1" target="$2" pw1 pw2

  while true; do
    read -r -s -p "  Enter password for ${user}: " pw1; echo
    read -r -s -p "  Retype password for ${user}: " pw2; echo
    [[ "$pw1" == "$pw2" ]] || { warn "Passwords do not match."; continue; }
    [[ -n "$pw1" ]] || { warn "Password cannot be empty."; continue; }
    break
  done

  install -d -m 0700 "$(dirname "$target")"
  printf '%s' "$pw1" | mkpasswd --method=yescrypt --stdin > "$target"
  unset pw1 pw2
  chmod 0400 "$target"
  info "Wrote: $target"
}

# Strip fileSystems."...", swapDevices, and boot.initrd.luks blocks from nixos-generate-config output.
# Tracks brace/bracket depth so arbitrarily nested blocks are handled correctly.
strip_fs_and_swap() {
  awk '
    BEGIN { skip = 0; depth = 0; saw_open = 0 }

    # Detect the start of a fileSystems, swapDevices, or boot.initrd.luks declaration
    !skip && (/^[[:space:]]*fileSystems\./ || /^[[:space:]]*swapDevices/ || /^[[:space:]]*boot\.initrd\.luks/) {
      skip = 1; depth = 0; saw_open = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{" || c == "[") { depth++; saw_open = 1 }
        if (c == "}" || c == "]") depth--
      }
      if (saw_open && depth <= 0) skip = 0
      next
    }

    # Inside a block being stripped — track delimiter depth
    skip {
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{" || c == "[") { depth++; saw_open = 1 }
        if (c == "}" || c == "]") depth--
      }
      if (saw_open && depth <= 0) skip = 0
      next
    }

    { print }
  ' | cat -s  # squeeze consecutive blank lines left by removed blocks
}

# ── Preflight ───────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || fail "Run as root."

for cmd in lsblk findmnt sgdisk partprobe mkfs.fat cryptsetup mkfs.btrfs mount umount \
           btrfs swapon swapoff nixos-generate-config nixos-install \
           sed awk grep mkpasswd mountpoint; do
  need_cmd "$cmd"
done

[[ -f "$REPO_ROOT/flake.nix" && -d "$REPO_ROOT/hosts/nixos" ]] \
  || fail "Could not locate repo root from script path: $REPO_ROOT
Run this script from inside your repo checkout."

# ── Phase 0: Select and confirm target disk ──────────────────────────────
phase "Phase 0 — Disk selection and confirmation"

echo "Repo root: $REPO_ROOT"
echo
echo "Available disks:"
lsblk -dpno NAME,SIZE,MODEL,TYPE | grep -E 'disk$' | while read -r name size model _; do
  printf "  %-12s %8s  %s\n" "$name" "$size" "$model"
done
echo

# Prompt for target disk
read -r -p "Enter the target disk (e.g., /dev/sda or /dev/nvme0n1): " DISK
[[ -b "$DISK" ]] || fail "Not a block device: $DISK"
[[ "$(lsblk -dno TYPE "$DISK")" == "disk" ]] || fail "Not a disk device: $DISK"

# Determine partition naming scheme (nvme uses p1, sda uses 1)
if [[ "$DISK" =~ nvme ]]; then
  BOOT_PART="${DISK}p1"
  CRYPT_PART="${DISK}p2"
else
  BOOT_PART="${DISK}1"
  CRYPT_PART="${DISK}2"
fi

# Warn about data destruction
echo
echo "WARNING: This will DESTROY ALL DATA on $DISK"
echo "  - Create new GPT partition table"
echo "  - EFI partition:   $BOOT_PART  (1 GiB, FAT32, label: NIXBOOT)"
echo "  - LUKS partition:  $CRYPT_PART  (rest of disk, LUKS2, label: NIXCRYPT)"
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$DISK"
echo
confirm_keyword "DESTROY" "Type DESTROY to wipe the entire disk and proceed:"

# ── Phase 1: Format ────────────────────────────────────────────────────
phase "Phase 1 — Formatting"

umount -R "$MNT" >/dev/null 2>&1 || true
swapoff -a >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true

# Create new GPT partition table and partitions
echo "Creating GPT partition table on $DISK..."
sgdisk -Z "$DISK"  # Zap (destroy) existing partition table
sgdisk -o "$DISK"  # Create new GPT

# Create EFI partition (1 GiB) - partition 1
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:NIXBOOT "$DISK"

# Create LUKS partition (rest of disk) - partition 2
sgdisk -n 2:0:0 -t 2:8309 -c 2:NIXCRYPT "$DISK"

# Inform kernel of partition table changes
partprobe "$DISK" || sleep 2

# Wait for partitions to appear
for _ in {1..10}; do
  [[ -b "$BOOT_PART" && -b "$CRYPT_PART" ]] && break
  sleep 0.5
done
[[ -b "$BOOT_PART" ]] || fail "EFI partition did not appear: $BOOT_PART"
[[ -b "$CRYPT_PART" ]] || fail "LUKS partition did not appear: $CRYPT_PART"

# Verify partitions are not mounted
findmnt -rn -S "$BOOT_PART" >/dev/null 2>&1 && fail "EFI partition is already mounted: $BOOT_PART"
findmnt -rn -S "$CRYPT_PART" >/dev/null 2>&1 && fail "LUKS partition is already mounted: $CRYPT_PART"

mkfs.fat -F 32 -n NIXBOOT "$BOOT_PART"

echo
echo "You will now set the LUKS passphrase for $CRYPT_PART."
cryptsetup luksFormat --type luks2 "$CRYPT_PART"
cryptsetup open "$CRYPT_PART" cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# ── Phase 2: Btrfs subvolumes ──────────────────────────────────────────
phase "Phase 2 — Creating Btrfs subvolumes"

mount /dev/mapper/cryptroot "$MNT"
for sv in @nix @persist @log @swap @home-daily @home-paranoid; do
  btrfs subvolume create "$MNT/$sv"
  info "Created subvolume $sv"
done
chattr +C "$MNT/@swap"
umount "$MNT"

# ── Phase 3: Mount target layout ───────────────────────────────────────
phase "Phase 3 — Mounting target layout"

mount -t tmpfs none "$MNT" -o mode=755,size=4G
mkdir -p "$MNT"/{boot,nix,persist,var/log,home/player,swap,etc}

mount -o subvol=@nix,compress=zstd,noatime          /dev/mapper/cryptroot "$MNT/nix"
mount -o subvol=@persist,compress=zstd,noatime       /dev/mapper/cryptroot "$MNT/persist"
chmod 700 "$MNT/persist"
mkdir -p "$MNT/persist/secrets" "$MNT/persist/home/ghost"
mount -o subvol=@log,compress=zstd,noatime           /dev/mapper/cryptroot "$MNT/var/log"
mount -o subvol=@home-daily,compress=zstd,noatime    /dev/mapper/cryptroot "$MNT/home/player"
mount -o subvol=@home-paranoid,compress=zstd,noatime /dev/mapper/cryptroot "$MNT/persist/home/ghost"
chmod 700 "$MNT/persist/home/ghost"
mount -o subvol=@swap,noatime,nodatacow              /dev/mapper/cryptroot "$MNT/swap"
mount -t vfat -o fmask=0077,dmask=0077               "$BOOT_PART" "$MNT/boot"

# Verify every mount point is actually mounted
for mp in "$MNT" "$MNT/boot" "$MNT/nix" "$MNT/persist" "$MNT/var/log" \
          "$MNT/home/player" "$MNT/persist/home/ghost" "$MNT/swap"; do
  mountpoint -q "$mp" || fail "$mp is not a mount point — mount sequence failed"
done
info "All mount points verified"

# Swapfile
btrfs filesystem mkswapfile --size 8g --uuid clear "$MNT/swap/swapfile"
swapon "$MNT/swap/swapfile" && swapoff "$MNT/swap/swapfile" \
  || fail "Swapfile activation test failed. Check Btrfs configuration."
info "Swapfile test: OK"

findmnt -R "$MNT"

# ── Phase 4: Stage repo + hardware config ──────────────────────────────
phase "Phase 4 — Staging repo and hardware config"

TARGET_REPO="$MNT/etc/nixos"
rm -rf "$TARGET_REPO"
mkdir -p "$MNT/etc"
cp -a "$REPO_ROOT" "$TARGET_REPO"
rm -rf "$TARGET_REPO/.git" "$TARGET_REPO/result" 2>/dev/null || true
info "Repo copied to $TARGET_REPO"

# Generate hardware scan.
# Use --show-hardware-config (outputs to stdout, no file side-effects) when
# available; fall back to file-based generation otherwise.
HW_RAW="$(mktemp)"
CLEANUP_FILES+=("$HW_RAW")

if nixos-generate-config --show-hardware-config --root "$MNT" > "$HW_RAW" 2>/dev/null; then
  info "Generated hardware config via --show-hardware-config"
else
  # Fallback: generates files into $MNT/etc/nixos/ (inside the repo copy).
  # Grab the hardware config, then clean up the generated files.
  warn "--show-hardware-config unavailable, falling back to file-based generation"
  nixos-generate-config --root "$MNT"
  if [[ -f "$TARGET_REPO/hardware-configuration.nix" ]]; then
    mv "$TARGET_REPO/hardware-configuration.nix" "$HW_RAW"
  elif [[ -f "$MNT/etc/nixos/hardware-configuration.nix" ]]; then
    mv "$MNT/etc/nixos/hardware-configuration.nix" "$HW_RAW"
  else
    fail "nixos-generate-config did not produce hardware-configuration.nix"
  fi
  # Remove the boilerplate configuration.nix that nixos-generate-config drops
  rm -f "$TARGET_REPO/configuration.nix" 2>/dev/null || true
fi

# Strip fileSystems, swapDevices, and boot.initrd.luks — the repo defines its own in fs-layout.nix
strip_fs_and_swap < "$HW_RAW" > "$TARGET_REPO/hosts/nixos/hardware-target.nix"
info "Wrote hardware-target.nix (fileSystems + swapDevices + boot.initrd.luks stripped)"

echo
if confirm_yes "Review hardware-target.nix before continuing?"; then
  echo "──────────────────────────────────────────────────"
  nano "$TARGET_REPO/hosts/nixos/hardware-target.nix"
  echo "──────────────────────────────────────────────────"
  echo
  confirm_yes "Does this look correct? Continue?" || { echo "Aborted. Fix manually at: $TARGET_REPO/hosts/nixos/hardware-target.nix"; exit 1; }
fi

# ── Phase 5: User passwords ────────────────────────────────────────────
phase "Phase 5 — Setting user passwords"

write_password_hash "ghost"  "$MNT/persist/secrets/ghost-password.hash"
write_password_hash "player" "$MNT/persist/secrets/player-password.hash"
# Verify hashes were actually written
for f in "$MNT/persist/secrets/player-password.hash" \
         "$MNT/persist/secrets/ghost-password.hash"; do
  [[ -s "$f" ]] || fail "Password hash file is empty or missing: $f"
done
info "Password hashes verified"

# ── Phase 6: Flake check ───────────────────────────────────────────────
if confirm_yes "Run 'nix flake check' on the staged repo?"; then
  phase "Phase 6 — Flake check"
  (cd "$TARGET_REPO" && nix --extra-experimental-features 'nix-command flakes' flake check)
fi

# ── Phase 7: Install ───────────────────────────────────────────────────
phase "Phase 7 — nixos-install"

echo "Command: nixos-install --flake $TARGET_REPO#nixos --no-root-passwd"
confirm_yes "Proceed with nixos-install?" \
  || { info "Stopped before nixos-install. Repo staged at $TARGET_REPO"; exit 0; }

nixos-install --flake "$TARGET_REPO#nixos" --no-root-passwd

# ── Done ────────────────────────────────────────────────────────────────
phase "Install complete"
cat <<'EOF'
Before rebooting, review:
  /mnt/etc/nixos/docs/pipeline/INSTALL-GUIDE.md
  /mnt/etc/nixos/docs/pipeline/TEST-PLAN.md

After reboot:
  1. Choose the daily specialisation first.
  2. Follow first-boot edits in docs/pipeline/INSTALL-GUIDE.md.
  3. Run daily-first checks in docs/pipeline/TEST-PLAN.md.
  4. Only after daily is good, continue with paranoid validation.
EOF
