#!/usr/bin/env bash
# Runtime: Steam + gamescope + gamemode + NT sync.
# Template-agnostic: checks myOS.gaming.enable instead of profile name.
source "${BASH_SOURCE%/*}/../lib/common.sh"

# Check if gaming is enabled in this configuration
gaming_enabled=$(config_value "myOS.gaming.enable" | jq_cmd -r 'select(type=="boolean")')
if [[ "$gaming_enabled" != "true" ]]; then
  skip "myOS.gaming.enable != true - gaming not configured"
  exit 0
fi

# Discover active users (template-agnostic)
mapfile -t active_users < <(detect_active_users)

if [[ ${#active_users[@]} -eq 0 ]]; then
  warn "no active users found"
  daily_user=""  # Will fall back to checks without user verification
else
  daily_user="${active_users[0]}"
  info "testing with active user: $daily_user"
fi

describe "Steam + steam-run wrappers (myOS.gaming.steam.enable)"
steam_enabled=$(config_value "myOS.gaming.steam.enable" | jq_cmd -r 'select(type=="boolean")')
if [[ "$steam_enabled" != "true" ]]; then
  info "myOS.gaming.steam.enable != true - Steam not configured"
fi

for c in steam steam-run; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    fail "$c missing from PATH"
  fi
done

describe "gamescope + gamemode (myOS.gaming.gamescope/gamemode.enable)"
for c in gamescope gamemoderun; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    fail "$c missing from PATH"
  fi
done

describe "gamescope has capSysNice (wrapper setcap)"
# Per modules/desktop/gaming.nix: programs.gamescope.capSysNice = true.
wrapper_path=$(command -v gamescope 2>/dev/null || true)
if [[ -n "$wrapper_path" ]]; then
  # Follow symlinks into /run/wrappers for the setuid/setcap wrapper.
  wrapped=$(readlink -f "$wrapper_path" 2>/dev/null || true)
  if getcap "$wrapped" 2>/dev/null | grep -q 'cap_sys_nice'; then
    pass "gamescope wrapper has cap_sys_nice"
  elif getcap "/run/wrappers/bin/gamescope" 2>/dev/null | grep -q 'cap_sys_nice'; then
    pass "/run/wrappers/bin/gamescope has cap_sys_nice"
  else
    warn "cap_sys_nice not found on gamescope wrapper (getcap may require root)"
  fi
fi

describe "gaming sysctls applied"
assert_sysctl "net.ipv4.tcp_mtu_probing"              "1"
assert_sysctl "kernel.sched_cfs_bandwidth_slice_us"   "3000"
# The following CFS scheduler tunables were removed from sysctl in kernel 5.13+
# and moved to debugfs (/sys/kernel/debug/sched/). They have no sysctl equivalents:
# sched_latency_ns, sched_min_granularity_ns, sched_wakeup_granularity_ns,
# sched_migration_cost_ns, sched_nr_migrate, sched_tunable_scaling
assert_sysctl "kernel.split_lock_mitigate"            "0"
assert_sysctl "kernel.sched_rt_runtime_us"            "-1"

describe "NT sync kernel module (gaming feature)"
# NT sync is a gaming feature, enabled via myOS.gaming.* options
assert_module_loaded ntsync
if [[ -c /dev/ntsync ]]; then
  pass "/dev/ntsync exists"
else
  warn "/dev/ntsync character device missing"
fi

describe "gamemoded socket + groups"
if systemctl --user is-active --quiet gamemoded.service 2>/dev/null \
   || systemctl is-active --quiet gamemoded.service 2>/dev/null; then
  pass "gamemoded service active (user or system scope)"
else
  warn "gamemoded not currently active (it's typically socket-launched)"
fi
if getent group gamemode >/dev/null; then
  pass "gamemode group exists"
  if [[ -n "$daily_user" ]]; then
    if id -nG "$daily_user" | grep -qw gamemode; then
      pass "$daily_user is in gamemode group"
    else
      fail "$daily_user missing from gamemode group"
    fi
  fi
else
  fail "gamemode group missing"
fi
if getent group realtime >/dev/null; then
  pass "realtime group exists"
  if [[ -n "$daily_user" ]]; then
    if id -nG "$daily_user" | grep -qw realtime; then
      pass "$daily_user is in realtime group"
    else
      fail "$daily_user missing from realtime group (VR RT prio)"
    fi
  fi
else
  fail "realtime group missing"
fi

describe "Steam hardware udev rules"
if [[ -e /etc/udev/rules.d/70-steam-input.rules ]] \
   || find /run/current-system/sw/lib/udev -name '*steam*' 2>/dev/null | grep -q .; then
  pass "steam-hardware udev rules installed"
else
  warn "steam-hardware udev rules not located"
fi

describe "gaming env vars exported to system"
# modules/desktop/gaming.nix sets PROTON_USE_NTSYNC and ENABLE_GAMESCOPE_WSI.
if [[ "${PROTON_USE_NTSYNC:-}" == "1" ]]; then
  pass "PROTON_USE_NTSYNC exported to current session"
else
  if grep -Rq 'PROTON_USE_NTSYNC' /etc/profile.d/ 2>/dev/null \
     || grep -Rq 'PROTON_USE_NTSYNC' /etc/systemd/system-environment-generators/ 2>/dev/null; then
    pass "PROTON_USE_NTSYNC is set at system level"
  else
    warn "PROTON_USE_NTSYNC not observable"
  fi
fi
if [[ "${ENABLE_GAMESCOPE_WSI:-}" == "1" ]]; then
  pass "ENABLE_GAMESCOPE_WSI exported to current session"
fi
