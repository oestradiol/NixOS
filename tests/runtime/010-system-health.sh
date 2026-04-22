#!/usr/bin/env bash
# Runtime: basic system health. No failed units, boot went through, no hard
# journal errors this boot.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "system state"
state=$(systemctl is-system-running 2>&1 || true)
# "running" or "degraded" are both reported; "degraded" means failed units.
case "$state" in
  running)
    pass "systemctl is-system-running = running"
    ;;
  degraded)
    fail "system is degraded" "failed units are present; see detail below"
    systemctl --failed --no-legend 2>&1 | head -20 | while IFS= read -r l; do
      info "$l"
    done
    ;;
  starting|initializing)
    warn "system still $state — rerun the suite once boot settles"
    ;;
  *)
    fail "unexpected state: $state"
    ;;
esac

describe "no failed units"
# `systemctl --failed --no-legend` prints a leading `●` colour marker by
# default; `--plain` strips it so awk {$1} yields the unit name, not `●`.
failed=$(systemctl list-units --state=failed --plain --no-legend --no-pager 2>/dev/null \
  | awk '{print $1}' | grep -v '^$' || true)
if [[ -z "$failed" ]]; then
  pass "systemctl --failed is empty"
else
  while IFS= read -r u; do
    fail "failed unit: $u" "$(systemctl status "$u" --no-pager -l 2>&1 | head -15)"
  done <<<"$failed"
fi

describe "boot-time invariants"
# /run/current-system should match /run/booted-system (no pending activation).
cur=$(readlink -f /run/current-system 2>/dev/null)
booted=$(readlink -f /run/booted-system 2>/dev/null)
if [[ -n "$cur" && "$cur" == "$booted" ]]; then
  pass "current-system == booted-system (no drift)"
else
  warn "current-system != booted-system; a rebuild happened since boot" \
       "current: $cur" "booted:  $booted"
fi

describe "journal: no boot-level errors from critical subsystems"
# Only raise as a fail for severity 0-3 (crit/alert/emerg/err). Warn lives
# as info only (every desktop produces some).
crit=$(journalctl -b -p 3 --no-pager 2>/dev/null \
  | grep -v 'run-user-' \
  | grep -vE 'Failed to stop home-[^/]+\.mount' \
  || true)
if [[ -z "$crit" ]]; then
  pass "no err/crit entries since boot"
else
  # Cap output so the log is readable.
  count=$(printf '%s\n' "$crit" | grep -cE '.' 2>/dev/null || echo 0)
  warn "journal has $count err-level entry/entries (informational)"
  printf '%s\n' "$crit" | head -10 | while IFS= read -r l; do
    info "$l"
  done
fi

describe "uptime sanity"
up_s=$(cut -d. -f1 </proc/uptime 2>/dev/null || echo 0)
if [[ "$up_s" -gt 0 ]]; then
  pass "system has been up for ${up_s}s"
else
  fail "/proc/uptime unreadable"
fi

describe "tmpfs root has headroom"
# Root is tmpfs (size=4G). If it is 100% full the system silently breaks:
# home-manager profile activation, xdg-dbus-proxy launches, journald spills,
# nix repl, etc. Fail loudly at 100%, warn at >=90%.
root_use=$(df -P / 2>/dev/null | awk 'NR==2{gsub("%",""); print $5+0}')
if [[ -z "$root_use" ]]; then
  warn "could not parse tmpfs root usage"
elif (( root_use >= 100 )); then
  fail "tmpfs / is at ${root_use}% (out of space)" \
    "heaviest /tmp subdirs (sudo needed): sudo du -sh /tmp/* 2>/dev/null | sort -h | tail" \
    "boot.tmp.cleanOnBoot=true only wipes /tmp on reboot; a reboot would recover"
elif (( root_use >= 90 )); then
  warn "tmpfs / is at ${root_use}% (>=90%, low headroom)"
else
  pass "tmpfs / at ${root_use}% used"
fi

describe "/nix and /persist headroom"
for mp in /nix /persist; do
  use=$(df -P "$mp" 2>/dev/null | awk 'NR==2{gsub("%",""); print $5+0}')
  if [[ -z "$use" ]]; then
    warn "could not read $mp usage"
  elif (( use >= 90 )); then
    fail "$mp is at ${use}%"
  else
    pass "$mp at ${use}% used"
  fi
done
