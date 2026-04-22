#!/usr/bin/env bash
# Runtime: ClamAV — daily impermanence scan, weekly deep scan, updater,
# exclusion and target generation correctness.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "clamav binaries + updater service"
for c in clamscan freshclam; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    fail "$c missing from PATH"
  fi
done

# services.clamav.updater.enable = true → creates clamav-freshclam.service
assert_unit_exists clamav-freshclam.service "clamav-freshclam.service declared"
state=$(systemctl is-active clamav-freshclam.service 2>&1 || true)
case "$state" in
  active|activating) pass "clamav-freshclam state: $state" ;;
  inactive)          warn "clamav-freshclam not active (timer-driven is OK)" ;;
  failed)            fail "clamav-freshclam failed" "$(journalctl -u clamav-freshclam.service -n 20 --no-pager 2>/dev/null || true)" ;;
  *)                 info "clamav-freshclam state: $state" ;;
esac

describe "daily impermanence scan timer + service"
assert_unit_exists clamav-impermanence-scan.service
assert_unit_exists clamav-impermanence-scan.timer
assert_unit_enabled clamav-impermanence-scan.timer
# Check schedule: OnUnitActiveSec=1d
if systemctl cat clamav-impermanence-scan.timer 2>/dev/null | grep -qE 'OnUnitActiveSec=(1d|1day|24h|86400)'; then
  pass "clamav-impermanence-scan.timer: daily cadence"
else
  fail "clamav-impermanence-scan.timer cadence drift (expected 1d)"
fi

describe "weekly deep scan timer + service"
assert_unit_exists clamav-deep-scan.service
assert_unit_exists clamav-deep-scan.timer
assert_unit_enabled clamav-deep-scan.timer
if systemctl cat clamav-deep-scan.timer 2>/dev/null | grep -qE 'OnUnitActiveSec=(1w|7d|168h|604800)'; then
  pass "clamav-deep-scan.timer: weekly cadence"
else
  fail "clamav-deep-scan.timer cadence drift (expected 1w)"
fi

describe "clamav scripts exclude per-profile HOME of the other user"
# The unit's ExecStart is a generated unit-script; its body invokes the real
# scan script inline (another /nix/store path referenced by its full name).
# Follow the chain by grepping the unit-script body for /nix/store refs to
# the real clamav-impermanence-scan script.
unit_cat=$(systemctl cat clamav-impermanence-scan.service 2>/dev/null || true)
profile=$(detect_profile)

# Discover users from config
user_names_json=$(config_value "myOS.users.__names")
if [[ "$user_names_json" == "null" || "$user_names_json" == "[]" ]]; then
  fail "no users declared in myOS.users (framework misconfiguration)"
  exit 1
fi
mapfile -t all_users < <(echo "$user_names_json" | jq_cmd -r '.[]')

# First, extract the unit-script path from ExecStart.
unit_start=$(awk -F'=' '/^ExecStart=/{print $2; exit}' <<<"$unit_cat")
script_content=""
if [[ -n "$unit_start" && -r "$unit_start" ]]; then
  script_content=$(cat "$unit_start")
  # If the unit-script in turn calls another /nix/store script, follow it too.
  nested=$(grep -oE '/nix/store/[^" ]+clamav-impermanence-scan[^" ]*' <<<"$script_content" | grep -v 'unit-script' | head -1 || true)
  if [[ -n "$nested" && -r "$nested" ]]; then
    script_content="$script_content
$(cat "$nested")"
  fi
fi

if [[ -n "$script_content" ]]; then
  # Shared exclusion rules
  for excl in 'steamapps' 'Steam' 'Steam/steamapps' '.var/app' '/var/log/journal'; do
    if grep -Fq "$excl" <<<"$script_content"; then
      pass "clamav script excludes $excl"
    else
      warn "clamav script missing exclusion: $excl"
    fi
  done
  # Target set must include persisted state + /boot + nix profiles
  for target in /persist /var/lib /var/log /boot /nix/var/nix/profiles; do
    if grep -Fq "$target" <<<"$script_content"; then
      pass "clamav target includes $target"
    else
      fail "clamav target missing: $target"
    fi
  done
  # Profile-specific user home scanning
  for u in "${all_users[@]}"; do
    active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
    if [[ "$active" == "true" ]]; then
      # Active user's home should be scanned
      if grep -Fq "/home/$u" <<<"$script_content"; then
        pass "$profile: clamav scans /home/$u"
      else
        fail "$profile: /home/$u missing from clamav targets"
      fi
    else
      # Inactive user's persist home should NOT be scanned (they're not active)
      if grep -Fq "/persist/home/$u" <<<"$script_content"; then
        warn "$profile: /persist/home/$u is in clamav targets (may be intentional)"
      else
        pass "$profile: /persist/home/$u NOT in clamav targets (inactive user)"
      fi
    fi
  done
else
  warn "could not locate clamav-impermanence-scan generated script in /nix/store"
fi

describe "hardening on clamav units"
# Hardening baseline comes from modules/security/scanners.nix. ProtectSystem
# is intentionally NOT set on the scan services (they must read paths that
# live under /var/log + /boot + /nix/var/nix/profiles), so it is absent from
# the required list. It IS set on flatpak-repo.service per flatpak.nix.
# Report its absence as an informational warning — adding ProtectSystem=strict
# with matching ReadOnlyPaths= would make the scanners more defensible.
required_hardening=(
  NoNewPrivileges PrivateTmp PrivateDevices ProtectKernelTunables
  ProtectKernelLogs ProtectControlGroups ProtectClock ProtectHostname
  RestrictSUIDSGID RestrictNamespaces RestrictRealtime LockPersonality
  SystemCallArchitectures CapabilityBoundingSet
)
for u in clamav-impermanence-scan.service clamav-deep-scan.service; do
  cat_out=$(systemctl cat "$u" 2>/dev/null || true)
  for h in "${required_hardening[@]}"; do
    if grep -q "^${h}=" <<<"$cat_out"; then
      pass "$u has $h"
    else
      fail "$u missing $h hardening directive"
    fi
  done
  # Informational: ProtectSystem is absent today; flag for later.
  if grep -q '^ProtectSystem=' <<<"$cat_out"; then
    pass "$u has ProtectSystem (bonus)"
  else
    warn "$u lacks ProtectSystem=strict — consider adding alongside ReadOnlyPaths"
  fi
done
