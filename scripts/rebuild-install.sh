#!/usr/bin/env bash
# Guided installer for framework-backed NixOS flakes.
#
# The script keeps the install topology intentionally narrow:
#   - one EFI partition
#   - one LUKS root partition
#   - Btrfs subvolumes under that root
#   - tmpfs root baseline
#
# It no longer assumes this repo, this template, or fixed user names.
# Instead it evaluates a selected flake/config, resolves the pinned
# framework source that flake uses, and derives storage + password-hash
# targets from the configuration itself.
set -euo pipefail

MNT="/mnt"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CLEANUP_FILES=()

phase() { printf '\n\033[1;36m══ %s ══\033[0m\n' "$*"; }
info()  { printf '\033[1;34m>> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
fail()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() { rm -f "${CLEANUP_FILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

nix_cmd() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
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

prompt_default() {
  local prompt="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " answer
    printf '%s\n' "${answer:-$default}"
  else
    read -r -p "$prompt: " answer
    printf '%s\n' "$answer"
  fi
}

prompt_required() {
  local prompt="$1" default="${2:-}" value=""
  while [[ -z "$value" ]]; do
    value=$(prompt_default "$prompt" "$default")
  done
  printf '%s\n' "$value"
}

join_csv() {
  local IFS=','
  printf '%s' "$*"
}

write_password_hash() {
  local label="$1" target="$2" pw1 pw2

  while true; do
    read -r -s -p "  Enter password for ${label}: " pw1; echo
    read -r -s -p "  Retype password for ${label}: " pw2; echo
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

# Strip fileSystems."...", swapDevices, and boot.initrd.luks blocks from
# nixos-generate-config output. Tracks brace/bracket depth so arbitrarily
# nested blocks are handled correctly.
strip_fs_and_swap() {
  awk '
    BEGIN { skip = 0; depth = 0; saw_open = 0 }

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
  ' | cat -s
}

config_names_expr() {
  cat <<'NIX'
builtins.attrNames (builtins.getFlake (builtins.getEnv "TARGET_FLAKE_REF")).outputs.nixosConfigurations
NIX
}

framework_out_path_expr() {
  cat <<'NIX'
let
  flake = builtins.getFlake (builtins.getEnv "TARGET_FLAKE_REF");
in
if (flake ? inputs) && (flake.inputs ? hardening) then
  flake.inputs.hardening.outPath
else
  flake.outPath
NIX
}

config_summary_expr() {
  cat <<'NIX'
let
  ref = builtins.getEnv "TARGET_FLAKE_REF";
  configName = builtins.getEnv "TARGET_CONFIG_NAME";
  flake = builtins.getFlake ref;
  lib = flake.inputs.nixpkgs.lib;
  base = flake.outputs.nixosConfigurations.${configName};

  enabledUsers = lib.filterAttrs (_: u: u.enable) base.config.myOS.users;

  mkStorage = cfg: {
    enable = cfg.myOS.storage.enable;
    devices = {
      boot = cfg.myOS.storage.devices.boot;
      cryptroot = cfg.myOS.storage.devices.cryptroot;
    };
    subvolumes = {
      nix = cfg.myOS.storage.subvolumes.nix;
      persist = cfg.myOS.storage.subvolumes.persist;
      log = cfg.myOS.storage.subvolumes.log;
      swap = cfg.myOS.storage.subvolumes.swap;
    };
    rootTmpfs = {
      enable = cfg.myOS.storage.rootTmpfs.enable;
      size = cfg.myOS.storage.rootTmpfs.size;
    };
    tmpTmpfs = {
      enable = cfg.myOS.storage.tmpTmpfs.enable;
      size = cfg.myOS.storage.tmpTmpfs.size;
      options = cfg.myOS.storage.tmpTmpfs.options;
    };
    homeTmpfs = {
      size = cfg.myOS.storage.homeTmpfs.size;
    };
    swap = {
      enable = cfg.myOS.storage.swap.enable;
      sizeMiB = cfg.myOS.storage.swap.sizeMiB;
    };
    persistRoot = cfg.myOS.persistence.root;
  };

  mkUser = name: u: {
    inherit name;
    persistent = u.home.persistent;
    btrfsSubvol = u.home.btrfsSubvol;
  };

  mkHashEntries = label: cfg:
    builtins.concatMap
      (user:
        let path = cfg.users.users.${user}.hashedPasswordFile or null;
        in
        if path == null then
          [ ]
        else
          [{ inherit path user; source = label; }]
      )
      (builtins.attrNames cfg.users.users);

  specNames = builtins.attrNames (base.config.specialisation or { });
  specSummaries = map
    (spec:
      let
        specCfg = (base.extendModules {
          modules = [ base.config.specialisation.${spec}.configuration ];
        }).config;
      in {
        name = spec;
        storage = mkStorage specCfg;
        passwordHashEntries = mkHashEntries spec specCfg;
      })
    specNames;
in {
  storage = mkStorage base.config;
  users = lib.mapAttrsToList mkUser enabledUsers;
  specialisations = specSummaries;
  passwordHashEntries =
    mkHashEntries "toplevel" base.config
    ++ builtins.concatMap (spec: spec.passwordHashEntries) specSummaries;
}
NIX
}

guess_devices() {
  local default_boot="" default_crypt=""
  if [[ -b /dev/nvme0n1p1 ]]; then
    default_boot="/dev/nvme0n1p1"
  fi
  if [[ -b /dev/nvme0n1p5 ]]; then
    default_crypt="/dev/nvme0n1p5"
  fi

  if [[ -z "$default_boot" || -z "$default_crypt" ]]; then
    mapfile -t _parts < <(lsblk -lnpo NAME,TYPE | awk '$2 == "part" { print $1 }')
    if (( ${#_parts[@]} >= 2 )); then
      default_boot="${default_boot:-${_parts[0]}}"
      default_crypt="${default_crypt:-${_parts[$((${#_parts[@]} - 1))]}}"
    fi
  fi

  printf '%s\t%s\n' "$default_boot" "$default_crypt"
}

framework_template_hardware_path() {
  local template_root="$1"

  if [[ -f "$template_root/hosts/nixos/default.nix" ]]; then
    printf '%s\n' 'hosts/nixos/hardware-target.nix'
    return 0
  fi

  if [[ -f "$template_root/hardware-target.nix" || -f "$template_root/hardware-target.nix.example" ]]; then
    printf '%s\n' 'hardware-target.nix'
    return 0
  fi

  return 1
}

resolve_path_label() {
  local path="$1" prefix="$2"
  case "$path" in
    "${prefix}"/*) printf '%s\n' "${path##*/}" ;;
    *) printf '\n' ;;
  esac
}

# ── Preflight ───────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || fail "Run as root."

for cmd in lsblk findmnt sgdisk mkfs.fat cryptsetup mkfs.btrfs mount umount \
           btrfs swapon swapoff nixos-generate-config nixos-install \
           sed awk grep mkpasswd mountpoint jq realpath; do
  need_cmd "$cmd"
done

# ── Phase 0: Select flake, config, and template ────────────────────────
phase "Phase 0 — Flake, config, and template"

DEFAULT_FLAKE_REF=""
if [[ -f "$SCRIPT_REPO_ROOT/flake.nix" ]]; then
  DEFAULT_FLAKE_REF="$SCRIPT_REPO_ROOT"
fi

TARGET_FLAKE_REF="${1:-}"
if [[ -z "$TARGET_FLAKE_REF" ]]; then
  TARGET_FLAKE_REF=$(prompt_required "Target flake path or URL" "$DEFAULT_FLAKE_REF")
fi

TARGET_META="$(mktemp)"
CLEANUP_FILES+=("$TARGET_META")
nix_cmd flake metadata --json --no-write-lock-file "$TARGET_FLAKE_REF" > "$TARGET_META"

TARGET_SOURCE="$(jq -r '.path' "$TARGET_META")"
TARGET_DIR="$(jq -r '.locked.dir // .resolved.dir // .original.dir // ""' "$TARGET_META")"
TARGET_DIR="${TARGET_DIR#./}"
[[ "$TARGET_SOURCE" != "null" && -d "$TARGET_SOURCE" ]] || fail "Could not resolve target flake source path."

FRAMEWORK_SOURCE="$(
  TARGET_FLAKE_REF="$TARGET_FLAKE_REF" \
    nix_cmd eval --impure --raw --no-write-lock-file --expr "$(framework_out_path_expr)"
)"
[[ -d "$FRAMEWORK_SOURCE" ]] || fail "Could not resolve the framework source used by the selected flake."

info "Target flake: $TARGET_FLAKE_REF"
info "Target source: $TARGET_SOURCE"
info "Framework source: $FRAMEWORK_SOURCE"

HARDENING_NODE="$(jq -r '.locks.nodes.root.inputs.hardening // ""' "$TARGET_META")"
HAS_HARDENING_INPUT=0
if [[ -n "$HARDENING_NODE" ]]; then
  HAS_HARDENING_INPUT=1
fi

mapfile -t TEMPLATE_CHOICES < <(
  find "$FRAMEWORK_SOURCE/templates" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null \
    | LC_ALL=C sort \
    | sed "s#^$FRAMEWORK_SOURCE/##"
)

DEFAULT_TEMPLATE_PATH=""
if [[ -n "$TARGET_DIR" && "$TARGET_DIR" == templates/* ]]; then
  DEFAULT_TEMPLATE_PATH="$TARGET_DIR"
elif printf '%s\n' "${TEMPLATE_CHOICES[@]}" | grep -qx 'templates/default'; then
  DEFAULT_TEMPLATE_PATH='templates/default'
elif (( ${#TEMPLATE_CHOICES[@]} > 0 )); then
  DEFAULT_TEMPLATE_PATH="${TEMPLATE_CHOICES[0]}"
fi

if (( ${#TEMPLATE_CHOICES[@]} > 0 )); then
  info "Available framework templates:"
  for template in "${TEMPLATE_CHOICES[@]}"; do
    printf '  - %s\n' "$template"
  done
fi

FRAMEWORK_TEMPLATE_PATH=$(prompt_required "Framework template path" "$DEFAULT_TEMPLATE_PATH")
FRAMEWORK_TEMPLATE_ROOT="$FRAMEWORK_SOURCE/$FRAMEWORK_TEMPLATE_PATH"
[[ -d "$FRAMEWORK_TEMPLATE_ROOT" ]] || fail "Template path not found inside framework source: $FRAMEWORK_TEMPLATE_PATH"

RELATIVE_HARDWARE_TARGET="$(framework_template_hardware_path "$FRAMEWORK_TEMPLATE_ROOT" || true)"
[[ -n "$RELATIVE_HARDWARE_TARGET" ]] || fail \
  "Template $FRAMEWORK_TEMPLATE_PATH does not expose a supported hardware-target path."

CONFIG_NAMES_JSON="$(
  TARGET_FLAKE_REF="$TARGET_FLAKE_REF" \
    nix_cmd eval --impure --json --no-write-lock-file --expr "$(config_names_expr)"
)"
mapfile -t CONFIG_NAMES < <(jq -r '.[]' <<<"$CONFIG_NAMES_JSON")
(( ${#CONFIG_NAMES[@]} > 0 )) || fail "Selected flake exports no nixosConfigurations."

DEFAULT_CONFIG_NAME="${CONFIG_NAMES[0]}"
if (( ${#CONFIG_NAMES[@]} > 1 )); then
  info "Available nixosConfigurations:"
  for name in "${CONFIG_NAMES[@]}"; do
    printf '  - %s\n' "$name"
  done
fi
TARGET_CONFIG_NAME=$(prompt_required "nixosConfiguration attribute" "$DEFAULT_CONFIG_NAME")
printf '%s\n' "${CONFIG_NAMES[@]}" | grep -qx "$TARGET_CONFIG_NAME" \
  || fail "Unknown nixosConfiguration: $TARGET_CONFIG_NAME"

SUMMARY_FILE="$(mktemp)"
CLEANUP_FILES+=("$SUMMARY_FILE")
TARGET_FLAKE_REF="$TARGET_FLAKE_REF" TARGET_CONFIG_NAME="$TARGET_CONFIG_NAME" \
  nix_cmd eval --impure --json --no-write-lock-file --expr "$(config_summary_expr)" > "$SUMMARY_FILE"

STORAGE_ENABLE="$(jq -r '.storage.enable' "$SUMMARY_FILE")"
ROOT_TMPFS_ENABLE="$(jq -r '.storage.rootTmpfs.enable' "$SUMMARY_FILE")"
PERSIST_ROOT="$(jq -r '.storage.persistRoot' "$SUMMARY_FILE")"
BOOT_DEVICE_REF="$(jq -r '.storage.devices.boot' "$SUMMARY_FILE")"
CRYPTROOT_DEVICE_REF="$(jq -r '.storage.devices.cryptroot' "$SUMMARY_FILE")"
NIX_SUBVOL="$(jq -r '.storage.subvolumes.nix' "$SUMMARY_FILE")"
PERSIST_SUBVOL="$(jq -r '.storage.subvolumes.persist' "$SUMMARY_FILE")"
LOG_SUBVOL="$(jq -r '.storage.subvolumes.log' "$SUMMARY_FILE")"
SWAP_SUBVOL="$(jq -r '.storage.subvolumes.swap' "$SUMMARY_FILE")"
ROOT_TMPFS_SIZE="$(jq -r '.storage.rootTmpfs.size' "$SUMMARY_FILE")"
TMP_TMPFS_ENABLE="$(jq -r '.storage.tmpTmpfs.enable' "$SUMMARY_FILE")"
TMP_TMPFS_SIZE="$(jq -r '.storage.tmpTmpfs.size' "$SUMMARY_FILE")"
HOME_TMPFS_SIZE="$(jq -r '.storage.homeTmpfs.size' "$SUMMARY_FILE")"
EFFECTIVE_SWAP_ENABLE="$(jq -r '([.storage.swap.enable] + [.specialisations[].storage.swap.enable]) | any' "$SUMMARY_FILE")"
EFFECTIVE_SWAP_SIZE_MIB="$(jq -r '
  ([.specialisations[]
    | select(.storage.swap.enable)
    | .storage.swap.sizeMiB] | first)
  // (if .storage.swap.enable then .storage.swap.sizeMiB else null end)
  // .storage.swap.sizeMiB
' "$SUMMARY_FILE")"

[[ "$STORAGE_ENABLE" == "true" ]] || fail \
  "myOS.storage.enable is false for $TARGET_CONFIG_NAME. This installer only supports the framework-owned storage layout in this pass."
[[ "$ROOT_TMPFS_ENABLE" == "true" ]] || fail \
  "myOS.storage.rootTmpfs.enable is false for $TARGET_CONFIG_NAME. This installer currently supports the tmpfs-root baseline only."

info "Selected config: $TARGET_CONFIG_NAME"
info "Persist root: $PERSIST_ROOT"
info "Dedicated /tmp tmpfs: $TMP_TMPFS_ENABLE (size: $TMP_TMPFS_SIZE)"
info "Disk-backed swap required by selected config surface: $EFFECTIVE_SWAP_ENABLE"

mapfile -t USER_ROWS < <(jq -r '.users[] | [.name, (.persistent|tostring), .btrfsSubvol] | @tsv' "$SUMMARY_FILE")
mapfile -t PASSWORD_ROWS < <(
  jq -r '
    .passwordHashEntries
    | sort_by(.path)
    | group_by(.path)[]
    | [.[0].path, (map(.user) | unique | join(",")), (map(.source) | unique | join(","))] | @tsv
  ' "$SUMMARY_FILE"
)

# ── Phase 1: Disk selection ────────────────────────────────────────────
phase "Phase 1 — Disk selection"

echo "Selected flake: $TARGET_FLAKE_REF"
echo "Selected config: $TARGET_CONFIG_NAME"
echo "Framework template: $FRAMEWORK_TEMPLATE_PATH"
echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,MOUNTPOINTS
echo

IFS=$'\t' read -r DEFAULT_BOOT_PART DEFAULT_CRYPT_PART <<<"$(guess_devices)"
BOOT_PART=$(prompt_required "EFI partition device" "$DEFAULT_BOOT_PART")
CRYPT_PART=$(prompt_required "Encrypted root partition device" "$DEFAULT_CRYPT_PART")

[[ "$BOOT_PART" != "$CRYPT_PART" ]] || fail "EFI and encrypted-root partitions must differ."
[[ -b "$BOOT_PART" ]] || fail "EFI partition not found: $BOOT_PART"
[[ -b "$CRYPT_PART" ]] || fail "Encrypted root partition not found: $CRYPT_PART"
findmnt -rn -S "$BOOT_PART" >/dev/null 2>&1 && fail "EFI partition is already mounted: $BOOT_PART"
findmnt -rn -S "$CRYPT_PART" >/dev/null 2>&1 && fail "Encrypted root partition is already mounted: $CRYPT_PART"

BOOT_LABEL="$(resolve_path_label "$BOOT_DEVICE_REF" "/dev/disk/by-label")"
CRYPT_PARTLABEL="$(resolve_path_label "$CRYPTROOT_DEVICE_REF" "/dev/disk/by-partlabel")"

echo
echo "This script will ONLY reformat:"
echo "  EFI:   $BOOT_PART${BOOT_LABEL:+  (label → $BOOT_LABEL)}"
echo "  Linux: $CRYPT_PART${CRYPT_PARTLABEL:+  (partlabel → $CRYPT_PARTLABEL)}"
echo "All other partitions and disks are preserved."
echo
confirm_keyword "REFORMAT" "Type REFORMAT to wipe the above two partitions:"

# ── Phase 2: Formatting ────────────────────────────────────────────────
phase "Phase 2 — Formatting"

umount -R "$MNT" >/dev/null 2>&1 || true
swapoff -a >/dev/null 2>&1 || true
cryptsetup close cryptroot >/dev/null 2>&1 || true

if [[ -n "$CRYPT_PARTLABEL" ]]; then
  CRYPT_PARENT="/dev/$(lsblk -no PKNAME "$CRYPT_PART")"
  CRYPT_PARTNUM="$(cat "/sys/class/block/$(basename "$CRYPT_PART")/partition")"
  sgdisk -c "${CRYPT_PARTNUM}:${CRYPT_PARTLABEL}" "$CRYPT_PARENT"
fi

if [[ -n "$BOOT_LABEL" ]]; then
  mkfs.fat -F 32 -n "$BOOT_LABEL" "$BOOT_PART"
else
  warn "Boot device is not addressed via /dev/disk/by-label/*; formatting without assigning a label."
  mkfs.fat -F 32 "$BOOT_PART"
fi

echo
echo "You will now set the LUKS passphrase for $CRYPT_PART."
cryptsetup luksFormat --type luks2 "$CRYPT_PART"
cryptsetup open "$CRYPT_PART" cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# ── Phase 3: Btrfs subvolumes ──────────────────────────────────────────
phase "Phase 3 — Creating Btrfs subvolumes"

mount /dev/mapper/cryptroot "$MNT"

declare -A SUBVOLUME_SET=()
SUBVOLUME_SET["$NIX_SUBVOL"]=1
SUBVOLUME_SET["$PERSIST_SUBVOL"]=1
SUBVOLUME_SET["$LOG_SUBVOL"]=1
if [[ "$EFFECTIVE_SWAP_ENABLE" == "true" ]]; then
  SUBVOLUME_SET["$SWAP_SUBVOL"]=1
fi

for row in "${USER_ROWS[@]}"; do
  IFS=$'\t' read -r user_name user_persistent user_subvol <<<"$row"
  SUBVOLUME_SET["$user_subvol"]=1
done

for subvol in "${!SUBVOLUME_SET[@]}"; do
  btrfs subvolume create "$MNT/$subvol"
  info "Created subvolume $subvol"
done

if [[ "$EFFECTIVE_SWAP_ENABLE" == "true" ]]; then
  chattr +C "$MNT/$SWAP_SUBVOL"
fi

umount "$MNT"

# ── Phase 4: Mount target layout ───────────────────────────────────────
phase "Phase 4 — Mounting target layout"

mount -t tmpfs none "$MNT" -o "mode=755,size=$ROOT_TMPFS_SIZE"
mkdir -p "$MNT/boot" "$MNT/nix" "$MNT/var/log" "$MNT/home" "$MNT/etc" "$MNT$PERSIST_ROOT"

mount -o "subvol=$NIX_SUBVOL,compress=zstd,noatime" /dev/mapper/cryptroot "$MNT/nix"
mount -o "subvol=$PERSIST_SUBVOL,compress=zstd,noatime" /dev/mapper/cryptroot "$MNT$PERSIST_ROOT"
chmod 700 "$MNT$PERSIST_ROOT"
mkdir -p "$MNT$PERSIST_ROOT/secrets" "$MNT$PERSIST_ROOT/home"
mount -o "subvol=$LOG_SUBVOL,compress=zstd,noatime" /dev/mapper/cryptroot "$MNT/var/log"
mount -t vfat -o fmask=0077,dmask=0077 "$BOOT_PART" "$MNT/boot"

VERIFY_MOUNTS=( "$MNT" "$MNT/boot" "$MNT/nix" "$MNT$PERSIST_ROOT" "$MNT/var/log" )

for row in "${USER_ROWS[@]}"; do
  IFS=$'\t' read -r user_name user_persistent user_subvol <<<"$row"
  if [[ "$user_persistent" == "true" ]]; then
    mkdir -p "$MNT/home/$user_name"
    mount -o "subvol=$user_subvol,compress=zstd,noatime" /dev/mapper/cryptroot "$MNT/home/$user_name"
    VERIFY_MOUNTS+=( "$MNT/home/$user_name" )
  else
    mkdir -p "$MNT$PERSIST_ROOT/home/$user_name"
    mount -o "subvol=$user_subvol,compress=zstd,noatime" /dev/mapper/cryptroot "$MNT$PERSIST_ROOT/home/$user_name"
    chmod 700 "$MNT$PERSIST_ROOT/home/$user_name"
    VERIFY_MOUNTS+=( "$MNT$PERSIST_ROOT/home/$user_name" )
  fi
done

if [[ "$EFFECTIVE_SWAP_ENABLE" == "true" ]]; then
  mkdir -p "$MNT/swap"
  mount -o "subvol=$SWAP_SUBVOL,noatime,nodatacow" /dev/mapper/cryptroot "$MNT/swap"
  btrfs filesystem mkswapfile --size "${EFFECTIVE_SWAP_SIZE_MIB}M" --uuid clear "$MNT/swap/swapfile"
  swapon "$MNT/swap/swapfile" && swapoff "$MNT/swap/swapfile" \
    || fail "Swapfile activation test failed. Check Btrfs swap configuration."
  info "Swapfile test: OK"
  VERIFY_MOUNTS+=( "$MNT/swap" )
fi

for mp in "${VERIFY_MOUNTS[@]}"; do
  mountpoint -q "$mp" || fail "$mp is not a mount point — mount sequence failed"
done
info "All mount points verified"

findmnt -R "$MNT"

# ── Phase 5: Stage flake + framework source ────────────────────────────
phase "Phase 5 — Staging flake and hardware config"

TARGET_STAGE_ROOT="$MNT/etc/nixos"
TARGET_ASSET_ROOT="$TARGET_STAGE_ROOT"
INSTALL_FLAKE_PATH="$TARGET_STAGE_ROOT"
if [[ -n "$TARGET_DIR" ]]; then
  TARGET_ASSET_ROOT="$TARGET_STAGE_ROOT/$TARGET_DIR"
  INSTALL_FLAKE_PATH="$TARGET_ASSET_ROOT"
fi

rm -rf "$TARGET_STAGE_ROOT"
mkdir -p "$TARGET_STAGE_ROOT"
cp -a "$TARGET_SOURCE/." "$TARGET_STAGE_ROOT"
rm -rf "$TARGET_STAGE_ROOT/.git" "$TARGET_STAGE_ROOT/result" 2>/dev/null || true
info "Staged flake source at $TARGET_STAGE_ROOT"

if (( HAS_HARDENING_INPUT )) && [[ "$(realpath "$FRAMEWORK_SOURCE")" != "$(realpath "$TARGET_SOURCE")" ]]; then
  FRAMEWORK_VENDOR_ROOT="$TARGET_STAGE_ROOT/.framework/hardening"
  rm -rf "$FRAMEWORK_VENDOR_ROOT"
  mkdir -p "$(dirname "$FRAMEWORK_VENDOR_ROOT")"
  cp -a "$FRAMEWORK_SOURCE/." "$FRAMEWORK_VENDOR_ROOT"

  FRAMEWORK_VENDOR_REL="$(realpath --relative-to="$INSTALL_FLAKE_PATH" "$FRAMEWORK_VENDOR_ROOT")"
  (
    cd "$INSTALL_FLAKE_PATH"
    nix_cmd flake lock --override-input hardening "path:$FRAMEWORK_VENDOR_REL"
  )
  info "Vendored framework source into $FRAMEWORK_VENDOR_ROOT"
fi

TARGET_HARDWARE_PATH="$TARGET_ASSET_ROOT/$RELATIVE_HARDWARE_TARGET"
mkdir -p "$(dirname "$TARGET_HARDWARE_PATH")"

HW_RAW="$(mktemp)"
CLEANUP_FILES+=("$HW_RAW")

if nixos-generate-config --show-hardware-config --root "$MNT" > "$HW_RAW" 2>/dev/null; then
  info "Generated hardware config via --show-hardware-config"
else
  warn "--show-hardware-config unavailable, falling back to file-based generation"
  nixos-generate-config --root "$MNT"
  if [[ -f "$TARGET_HARDWARE_PATH" ]]; then
    mv "$TARGET_HARDWARE_PATH" "$HW_RAW"
  elif [[ -f "$MNT/etc/nixos/hardware-configuration.nix" ]]; then
    mv "$MNT/etc/nixos/hardware-configuration.nix" "$HW_RAW"
  else
    fail "nixos-generate-config did not produce a hardware configuration file"
  fi
  rm -f "$MNT/etc/nixos/configuration.nix" 2>/dev/null || true
fi

strip_fs_and_swap < "$HW_RAW" > "$TARGET_HARDWARE_PATH"
info "Wrote hardware-target.nix at $TARGET_HARDWARE_PATH"

echo
if confirm_yes "Review hardware-target before continuing?"; then
  echo "──────────────────────────────────────────────────"
  nano "$TARGET_HARDWARE_PATH"
  echo "──────────────────────────────────────────────────"
  echo
  confirm_yes "Does this look correct? Continue?" \
    || { echo "Aborted. Fix manually at: $TARGET_HARDWARE_PATH"; exit 1; }
fi

# ── Phase 6: Password hash targets ─────────────────────────────────────
phase "Phase 6 — Setting password hash files"

if (( ${#PASSWORD_ROWS[@]} == 0 )); then
  info "No hashedPasswordFile targets were discovered for $TARGET_CONFIG_NAME."
else
  for row in "${PASSWORD_ROWS[@]}"; do
    IFS=$'\t' read -r hash_path hash_users hash_sources <<<"$row"
    [[ "$hash_path" == /* ]] || fail "Discovered hashedPasswordFile is not absolute: $hash_path"
    label="users: ${hash_users} | configs: ${hash_sources}"
    write_password_hash "$label" "$MNT$hash_path"
  done

  for row in "${PASSWORD_ROWS[@]}"; do
    IFS=$'\t' read -r hash_path _hash_users _hash_sources <<<"$row"
    [[ -s "$MNT$hash_path" ]] || fail "Password hash file is empty or missing: $MNT$hash_path"
  done
  info "Password hashes verified"
fi

# ── Phase 7: Flake check ───────────────────────────────────────────────
if confirm_yes "Run 'nix flake check' on the staged flake?"; then
  phase "Phase 7 — Flake check"
  (cd "$INSTALL_FLAKE_PATH" && nix_cmd flake check)
fi

# ── Phase 8: Install ───────────────────────────────────────────────────
phase "Phase 8 — nixos-install"

echo "Command: nixos-install --flake $INSTALL_FLAKE_PATH#$TARGET_CONFIG_NAME --no-root-passwd"
confirm_yes "Proceed with nixos-install?" \
  || { info "Stopped before nixos-install. Staged flake at $INSTALL_FLAKE_PATH"; exit 0; }

nixos-install --flake "$INSTALL_FLAKE_PATH#$TARGET_CONFIG_NAME" --no-root-passwd

# ── Done ────────────────────────────────────────────────────────────────
phase "Install complete"
cat <<EOF
Before rebooting, review:
  $TARGET_STAGE_ROOT/docs/pipeline/INSTALL-GUIDE.md
  $TARGET_STAGE_ROOT/docs/pipeline/TEST-PLAN.md

After reboot:
  1. Validate the selected nixosConfiguration ($TARGET_CONFIG_NAME).
  2. If specialisations were discovered, boot the intended one first.
  3. Follow the first-boot and test-plan notes in the staged repo.
EOF
