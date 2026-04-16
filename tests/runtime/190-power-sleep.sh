#!/usr/bin/env bash
# Runtime: power/sleep posture. allowSleep=false → sleep targets masked,
# power management NVIDIA tie-in, earlyoom, zram, fstrim.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "sleep / suspend / hibernate targets are masked (allowSleep=false)"
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  state=$(systemctl is-enabled "$t" 2>&1 || true)
  # NixOS sets `systemd.targets.sleep.enable = false` which should disable/mask.
  case "$state" in
    masked|disabled)
      pass "$t: $state"
      ;;
    enabled|alias|static)
      fail "$t is $state but allowSleep=false policy says it must be masked/disabled"
      ;;
    *)
      warn "$t: $state"
      ;;
  esac
done

describe "nohibernate on kernel cmdline"
if grep -qw 'nohibernate' /proc/cmdline; then
  pass "nohibernate on kernel cmdline"
else
  warn "nohibernate token not on cmdline (fs-layout should have added it via impermanence)"
fi

describe "powerManagement.enable tie-in"
# With allowSleep=false, NixOS sets powerManagement.enable=false, which means
# systemd-sleep helper is not active and no pm-utils hooks are installed.
if systemctl is-active --quiet suspend.target 2>/dev/null; then
  fail "suspend.target active right now"
else
  pass "suspend.target not active"
fi

describe "earlyoom"
assert_service_active earlyoom.service
# Parameters: "-M 409600,307200 -S 409600,307200"
if systemctl cat earlyoom.service 2>/dev/null | grep -q '409600,307200'; then
  pass "earlyoom thresholds match policy"
else
  warn "earlyoom thresholds drifted"
fi

describe "zram swap"
if awk '{print $1}' /proc/swaps 2>/dev/null | grep -q '^/dev/zram'; then
  pass "zram is active"
else
  fail "no /dev/zram* in /proc/swaps"
fi
# algorithm=zstd, memoryPercent=50. Check via sys.
if [[ -r /sys/block/zram0/comp_algorithm ]]; then
  algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
  if [[ "$algo" == *'[zstd]'* ]]; then
    pass "zram0 algorithm = zstd"
  else
    fail "zram0 algorithm drift" "$algo"
  fi
fi

describe "fstrim enabled (periodic SSD TRIM)"
if systemctl cat fstrim.timer >/dev/null 2>&1; then
  assert_unit_enabled fstrim.timer
else
  fail "fstrim.timer unit missing"
fi
