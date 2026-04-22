#!/usr/bin/env bash
# Runtime: impermanence bind-mounts and allowlisted persistence surfaces.
# Template-agnostic: discovers users from myOS.users and checks their
# persistence configuration dynamically.
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

profile=$(detect_profile)
describe "impermanence: profile = $profile"

# Discover declared users from framework config
user_names_json=$(config_value "myOS.users.__names")
if [[ "$user_names_json" == "null" || "$user_names_json" == "[]" ]]; then
  fail "no users declared in myOS.users"
  exit 1
fi

mapfile -t all_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
info "declared users: ${all_users[*]}"

describe "core persisted system directories are visible"
for p in \
  /var/lib/nixos \
  /var/lib/systemd \
  /var/lib/aide \
  /var/lib/sbctl \
  /etc/NetworkManager/system-connections \
  /var/lib/flatpak; do
  # Either they are symlinked into /persist, or they are bind-mounted from it.
  if [[ -L "$p" ]]; then
    target=$(readlink -f "$p" 2>/dev/null)
    case "$target" in
      /persist/*) pass "$p -> $target (symlink into persist)" ;;
      *)          warn "$p symlink target outside /persist: $target" ;;
    esac
  elif findmnt -n "$p" >/dev/null 2>&1; then
    pass "$p is a bind mount"
  elif [[ -d "$p" ]]; then
    info "$p exists but is neither symlink nor bind mount"
  else
    warn "$p missing"
  fi
done

describe "core persisted system files"
# Files are bind-mounted from /persist by impermanence. /persist is 0700
# root-only, so `-e` fails as a normal user (can't stat the target). Accept
# the symlink existence (-L) and defer -e to the sudo branch.
for p in /etc/machine-id; do
  if [[ -L "$p" ]]; then
    tgt=$(readlink "$p" 2>/dev/null)
    pass "$p is a symlink (-> $tgt)"
    if sudo -n true 2>/dev/null; then
      if sudo -n test -e "$p"; then
        pass "$p target exists under /persist"
      else
        fail "$p symlink is dangling (target missing)"
      fi
    fi
  elif [[ -e "$p" ]]; then
    # Regular file (e.g. machine-id may be a plain file depending on wiring)
    pass "$p exists (plain file)"
  else
    fail "$p missing"
  fi
done

describe "SSH host keys (only if openssh enabled)"
if systemctl is-enabled --quiet sshd.service 2>/dev/null || systemctl is-enabled --quiet sshd.socket 2>/dev/null; then
  for p in \
    /etc/ssh/ssh_host_ed25519_key \
    /etc/ssh/ssh_host_ed25519_key.pub \
    /etc/ssh/ssh_host_rsa_key \
    /etc/ssh/ssh_host_rsa_key.pub; do
    if [[ -L "$p" ]]; then
      tgt=$(readlink "$p" 2>/dev/null)
      pass "$p is a symlink (-> $tgt)"
      if sudo -n true 2>/dev/null; then
        if sudo -n test -e "$p"; then
          pass "$p target exists under /persist"
        else
          fail "$p symlink is dangling (target missing)"
        fi
      fi
    elif [[ -e "$p" ]]; then
      pass "$p exists (plain file)"
    else
      fail "$p missing"
    fi
  done
else
  pass "SSH disabled - host key checks skipped (services.openssh.enable = false)"
fi
# machine-id must be non-empty and match /persist
if sudo -n test -r /persist/etc/machine-id 2>/dev/null; then
  mid=$(cat /etc/machine-id)
  pmid=$(sudo -n cat /persist/etc/machine-id)
  if [[ -n "$mid" && "$mid" == "$pmid" ]]; then
    pass "machine-id persisted and matches"
  else
    fail "machine-id divergence" "/etc: $mid" "/persist: $pmid"
  fi
fi

describe "per-user home persistence based on home.persistent setting"
# For each user, check if their home matches their persistence config
for u in "${all_users[@]}"; do
  persistent=$(config_value "myOS.users.${u}.home.persistent" | jq_cmd -r 'select(type=="boolean")')
  home_path="/home/$u"
  
  if [[ "$persistent" == "true" ]]; then
    # Home should be persistent (btrfs subvolume typically)
    if [[ -d "$home_path" ]]; then
      fs=$(findmnt -n -o FSTYPE "$home_path" 2>/dev/null || true)
      if [[ "$fs" == "btrfs" ]]; then
        pass "$u: /home/$u on btrfs (persistent)"
      elif [[ "$fs" == "tmpfs" ]]; then
        fail "$u: home.persistent=true but /home/$u is tmpfs"
      else
        info "$u: /home/$u on $fs"
      fi
    else
      warn "$u: /home/$u does not exist (may not be mounted yet)"
    fi
  else
    # Home should be tmpfs (or not mounted for inactive users)
    active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
    if [[ "$active" == "true" && -d "$home_path" ]]; then
      fs=$(findmnt -n -o FSTYPE "$home_path" 2>/dev/null || true)
      if [[ "$fs" == "tmpfs" ]]; then
        pass "$u: /home/$u on tmpfs (non-persistent)"
      elif [[ "$fs" == "btrfs" ]]; then
        warn "$u: home.persistent!=true but /home/$u is on btrfs"
      else
        info "$u: /home/$u on $fs"
      fi
    fi
  fi
done

describe "per-user allowlisted persistence directories"
# Check for allowlisted bind mounts from /persist/home/<user>/
persist_root=$(config_value "myOS.persistence.root" | jq_cmd -r 'select(type=="string")')
[[ -z "$persist_root" || "$persist_root" == "null" ]] && persist_root="/persist"

for u in "${all_users[@]}"; do
  active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
  # Only check active users with non-persistent homes (they use allowlists)
  if [[ "$active" != "true" ]]; then
    continue
  fi
  
  persistent=$(config_value "myOS.users.${u}.home.persistent" | jq_cmd -r 'select(type=="boolean")')
  if [[ "$persistent" == "true" ]]; then
    continue  # Full persistence doesn't use allowlist
  fi
  
  # Check for common allowlisted paths
  allowlist_paths=(
    ".gnupg"
    ".ssh"
    ".local/share/flatpak"
    ".local/share/keyrings"
    "Downloads"
    "Documents"
  )
  
  for rel in "${allowlist_paths[@]}"; do
    p="/home/$u/$rel"
    if [[ -L "$p" ]] || findmnt -n "$p" >/dev/null 2>&1; then
      pass "$u: allowlisted $rel"
    fi
  done
done
