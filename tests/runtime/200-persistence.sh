#!/usr/bin/env bash
# Runtime: impermanence bind-mounts and allowlisted persistence surfaces.
# Daily persists the full /home/player subvolume; paranoid persists an
# explicit allowlist under /persist/home/ghost.
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

profile=$(detect_profile)
describe "impermanence: profile = $profile"

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

describe "daily-only persistence surfaces"
if [[ "$profile" == "daily" ]]; then
  for p in /var/lib/bluetooth /var/lib/mullvad-vpn /etc/mullvad-vpn /var/lib/NetworkManager; do
    if [[ -e "$p" ]]; then
      # Prefer the impermanence-managed form (bind-mount or symlink).
      if [[ -L "$p" ]] || findmnt -n "$p" >/dev/null 2>&1; then
        pass "daily persists $p"
      else
        warn "$p exists but persistence form unclear"
      fi
    else
      fail "$p missing on daily"
    fi
  done
else
  for p in /var/lib/bluetooth /var/lib/mullvad-vpn /etc/mullvad-vpn; do
    if [[ -e "$p" ]]; then
      warn "$p unexpectedly present on paranoid"
    else
      pass "$p absent on paranoid (expected)"
    fi
  done
fi

describe "paranoid-only ghost allowlisted persistence"
if [[ "$profile" == "paranoid" ]]; then
  for rel in \
    Downloads Documents .gnupg .ssh .local/share/flatpak \
    .mozilla/safe-firefox .config/Signal .config/keepassxc \
    .local/share/KeePassXC .local/share/keyrings .local/share/applications \
    .var/app/org.signal.Signal; do
    p="/home/ghost/$rel"
    if [[ -e "$p" ]] || findmnt -n "$p" >/dev/null 2>&1; then
      pass "ghost allowlisted: $rel"
    else
      warn "ghost allowlist missing: $rel"
    fi
  done
  for f in .zsh_history; do
    p="/home/ghost/$f"
    if [[ -e "$p" ]]; then pass "ghost file allowlisted: $f"; else warn "ghost file allowlist missing: $f"; fi
  done
fi

describe "/home/player is persistent btrfs (daily)"
if [[ "$profile" == "daily" ]]; then
  fs=$(findmnt -n -o FSTYPE /home/player 2>/dev/null || true)
  assert_eq "$fs" "btrfs" "/home/player fstype = btrfs"
fi

describe "/home/ghost is tmpfs (paranoid)"
if [[ "$profile" == "paranoid" ]]; then
  fs=$(findmnt -n -o FSTYPE /home/ghost 2>/dev/null || true)
  assert_eq "$fs" "tmpfs" "/home/ghost fstype = tmpfs"
fi
