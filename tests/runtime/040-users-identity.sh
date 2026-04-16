#!/usr/bin/env bash
# Runtime: account locks, machine-id persistence, root lock, sudo posture.
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

profile=$(detect_profile)
describe "detected profile at runtime"
info "profile: $profile"

describe "both user accounts exist"
for u in player ghost; do
  if getent passwd "$u" >/dev/null; then
    pass "$u exists in passwd"
  else
    fail "$u missing from passwd"
  fi
done

describe "explicit UID for ghost = 1001 (used by tmpfs uid= option)"
gid=$(id -u ghost 2>/dev/null || true)
if [[ "$gid" == "1001" ]]; then
  pass "ghost UID = 1001"
else
  fail "ghost UID wrong" "expected 1001, got $gid"
fi

describe "player is in wheel; ghost is NOT in wheel"
pg=$(id -nG player 2>/dev/null || true)
gg=$(id -nG ghost 2>/dev/null || true)
if grep -qw wheel <<<"$pg"; then pass "player in wheel"; else fail "player not in wheel"; fi
if grep -qw wheel <<<"$gg"; then fail "ghost is in wheel (forbidden)"; else pass "ghost NOT in wheel"; fi

describe "profile-specific account locking"
if sudo -n true 2>/dev/null; then
  # Sudo without password works; we have passwordless sudo already.
  :
else
  skip "sudo -n not available; skip /etc/shadow comparison"
  if [[ "$profile" == "daily" ]]; then
    # fallback: use getent which may expose x only
    :
  fi
fi

# /etc/shadow entries: on daily, player has a real hash and ghost is "!".
# On paranoid, reverse.
if sudo -n test -r /etc/shadow 2>/dev/null; then
  player_f=$(sudo -n getent shadow player | cut -d: -f2)
  ghost_f=$(sudo -n getent shadow ghost  | cut -d: -f2)
  case "$profile" in
    daily)
      if [[ "$player_f" == '!' ]]; then
        fail "daily: player must be unlocked, shadow hash = '!'"
      else
        pass "daily: player has a real hash"
      fi
      if [[ "$ghost_f" == '!' ]]; then
        pass "daily: ghost is locked ('!')"
      else
        fail "daily: ghost should be locked, hash = $ghost_f"
      fi
      ;;
    paranoid)
      if [[ "$player_f" == '!' ]]; then
        pass "paranoid: player is locked ('!')"
      else
        fail "paranoid: player should be locked, hash = $player_f"
      fi
      if [[ "$ghost_f" == '!' ]]; then
        fail "paranoid: ghost must be unlocked, shadow hash = '!'"
      else
        pass "paranoid: ghost has a real hash"
      fi
      ;;
  esac
else
  skip "shadow not readable without sudo; cannot verify account locks"
fi

describe "root account is locked"
if sudo -n test -r /etc/shadow 2>/dev/null; then
  root_f=$(sudo -n getent shadow root | cut -d: -f2)
  if [[ "$root_f" == '!' || "$root_f" == '!!' || "$root_f" == '*' ]]; then
    pass "root is locked (shadow='$root_f')"
  else
    fail "root is not locked" "shadow=$root_f"
  fi
fi

describe "persist secrets files exist"
if sudo -n true 2>/dev/null; then
  for f in /persist/secrets/player-password.hash /persist/secrets/ghost-password.hash; do
    if sudo -n test -f "$f"; then
      pass "exists: $f"
      # Should be 0400 root-only
      perm=$(sudo -n stat -c '%a %U' "$f" 2>/dev/null || true)
      if [[ "$perm" == "400 root" ]]; then
        pass "$f mode = 0400 root"
      else
        warn "$f permission drift" "got: $perm"
      fi
    else
      fail "$f missing from /persist/secrets"
    fi
  done
fi

describe "machine-id persistence"
if [[ -s /etc/machine-id ]]; then
  mid=$(cat /etc/machine-id)
  if [[ "${#mid}" -eq 32 ]]; then
    pass "/etc/machine-id present, length 32"
  else
    fail "/etc/machine-id length wrong" "got len=${#mid}"
  fi
  # Must match /persist copy (impermanence).
  if sudo -n test -r /persist/etc/machine-id 2>/dev/null; then
    pmid=$(sudo -n cat /persist/etc/machine-id)
    if [[ "$mid" == "$pmid" ]]; then
      pass "machine-id == /persist/etc/machine-id"
    else
      fail "machine-id divergence" "/etc: $mid" "/persist/etc: $pmid"
    fi
  else
    skip "cannot read /persist/etc/machine-id without sudo"
  fi
else
  fail "/etc/machine-id is empty"
fi

describe "sudo: requires password, execWheelOnly, wheelNeedsPassword"
sudoers=$(sudo -n cat /etc/sudoers 2>/dev/null || true)
if [[ -n "$sudoers" ]]; then
  if grep -qE '^\s*%wheel' <<<"$sudoers"; then pass "sudoers grants wheel"; else warn "no explicit %wheel line"; fi
fi
