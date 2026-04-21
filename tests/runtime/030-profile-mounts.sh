#!/usr/bin/env bash
# Runtime: profile-mount-invariants.service must have succeeded, and the
# invariants it checks must still hold.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "profile-mount-invariants.service status"
# oneshot + RemainAfterExit → `active (exited)` when successful.
if systemctl is-active --quiet profile-mount-invariants.service; then
  pass "profile-mount-invariants.service is active"
else
  state=$(systemctl is-active profile-mount-invariants.service 2>&1 || true)
  fail "profile-mount-invariants.service state: $state" \
    "$(systemctl status profile-mount-invariants.service --no-pager -l 2>&1 | head -20)"
fi
assert_unit_enabled profile-mount-invariants.service

describe "invariant predicates (direct re-check)"
profile=$(detect_profile)
if [[ "$profile" == "daily" ]]; then
  assert_mountpoint     /home/player           "daily: /home/player mounted"
  assert_not_mountpoint /home/ghost            "daily: /home/ghost NOT mounted"
  assert_not_mountpoint /persist/home/ghost    "daily: /persist/home/ghost NOT mounted"
else
  assert_mountpoint     /home/ghost            "paranoid: /home/ghost mounted"
  assert_mountpoint     /persist/home/ghost    "paranoid: /persist/home/ghost mounted"
  assert_not_mountpoint /home/player           "paranoid: /home/player NOT mounted"
fi

describe "impermanence bind mounts present (paranoid-only persistence dirs)"
if [[ "$profile" == "paranoid" ]]; then
  for sub in Downloads Documents .gnupg .ssh .mozilla/safe-firefox \
             .local/share/flatpak .var/app/org.signal.Signal; do
    if mountpoint -q "/home/ghost/$sub" 2>/dev/null; then
      pass "paranoid impermanence bind: /home/ghost/$sub"
    else
      warn "paranoid impermanence bind missing: /home/ghost/$sub"
    fi
  done
fi

describe "cross-profile home paths cleanly absent from /proc/self/mounts"
# Check that the opposite profile's home is not mounted as a filesystem mountpoint.
# Note: impermanence bind mounts of subdirectories (e.g., /home/ghost/.config)
# are not mountpoints of /home/ghost itself and are filtered by this check.
if [[ "$profile" == "daily" ]]; then
  if awk '$2 == "/home/ghost" {found=1} END {exit !found}' /proc/self/mounts; then
    fail "daily profile leaks a /home/ghost mount into /proc/self/mounts"
  else
    pass "no /home/ghost mount on daily"
  fi
else
  if awk '$2 == "/home/player" {found=1} END {exit !found}' /proc/self/mounts; then
    fail "paranoid profile leaks a /home/player mount into /proc/self/mounts"
  else
    pass "no /home/player mount on paranoid"
  fi
fi
