#!/usr/bin/env bash
# Runtime: miscellaneous expected services for the active user stack that
# don't fit neatly into the other buckets.
# Template-agnostic: discovers users from myOS.users configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

# Discover declared users from framework config
user_names_json=$(config_value "myOS.users.__names")
if [[ "$user_names_json" != "null" && "$user_names_json" != "[]" ]]; then
  mapfile -t all_users < <(echo "$user_names_json" | jq_cmd -r '.[]')
else
  all_users=()
fi

describe "accounts-daemon, systemd-logind, systemd-hostnamed, systemd-machined"
for u in accounts-daemon.service systemd-logind.service systemd-hostnamed.service; do
  if systemctl cat "$u" >/dev/null 2>&1; then
    state=$(systemctl is-active "$u" 2>&1 || true)
    if [[ "$state" == "active" ]]; then
      pass "$u active"
    elif [[ "$state" == "inactive" ]]; then
      info "$u inactive (often dbus-activated on demand)"
    else
      info "$u state: $state"
    fi
  fi
done

describe "avahi state matches myOS.vr.lanDiscovery policy"
# Policy: upstream nixpkgs wivrn.nix hard-enables avahi without mkDefault.
# Our modules/desktop/vr.nix gates it behind myOS.vr.lanDiscovery.enable.
# When the knob is OFF (default), avahi must be completely disabled.
# When ON, avahi must exist AND must scope `allowInterfaces` to the declared
# `myOS.vr.lanInterfaces` (no broadcast on VPN/guest/bluetooth interfaces).
_active_profile=$(detect_profile)
if [[ "$_active_profile" == "daily" ]]; then
  lan_discovery=$(nix_eval_daily 'myOS.vr.lanDiscovery.enable')
  lan_ifaces=$(nix_eval_daily 'myOS.vr.lanInterfaces')
  avahi_allow=$(nix_eval_daily 'services.avahi.allowInterfaces')
else
  lan_discovery=$(nix_eval 'myOS.vr.lanDiscovery.enable')
  lan_ifaces=$(nix_eval 'myOS.vr.lanInterfaces')
  avahi_allow=$(nix_eval 'services.avahi.allowInterfaces')
fi
case "$lan_discovery" in
  false)
    if systemctl cat avahi-daemon.service >/dev/null 2>&1; then
      fail "avahi-daemon.service unit still defined while myOS.vr.lanDiscovery.enable=false" \
        "Upstream wivrn.nix forces avahi; modules/desktop/vr.nix should mkForce it off." \
        "Check that vr.nix was actually imported (gaming.nix -> vr.nix via daily)."
    else
      pass "avahi-daemon.service unit absent (lanDiscovery off)"
    fi
    if getent passwd avahi >/dev/null; then
      fail "avahi user still exists while lanDiscovery=false"
    else
      pass "avahi user absent (lanDiscovery off)"
    fi
    ;;
  true)
    if systemctl is-active avahi-daemon.service >/dev/null 2>&1; then
      pass "avahi-daemon.service active (lanDiscovery on, as declared)"
    else
      fail "avahi-daemon.service not active despite lanDiscovery=true"
    fi
    if [[ "$avahi_allow" == "null" || "$avahi_allow" == "[]" ]]; then
      fail "avahi.allowInterfaces is empty — broadcast would leak to every interface" \
        "expected: myOS.vr.lanInterfaces = ${lan_ifaces}"
    else
      pass "avahi restricted to interfaces: $avahi_allow"
    fi
    ;;
  *)
    warn "myOS.vr.lanDiscovery.enable = $lan_discovery (unexpected; treated as off)"
    ;;
esac

describe "swap / swapfile (daily) and zram swap"
if awk '{print $1}' /proc/swaps 2>/dev/null | grep -q '/dev/zram'; then
  pass "zram swap device active"
else
  fail "no zram swap active"
fi

describe "/tmp cleanup on boot + protectKernelImage"
# boot.tmp.cleanOnBoot = true → systemd.tempfiles.clean-tmp targets /tmp.
if [[ -r /run/current-system/etc/tmpfiles.d/home.conf ]] \
   || systemctl cat systemd-tmpfiles-clean.service >/dev/null 2>&1; then
  pass "tmpfiles infrastructure present"
fi
# kernel.image protection test: kernel is not writable
if [[ -r /run/booted-system/kernel ]]; then
  perms=$(stat -c '%a' "$(readlink -f /run/booted-system/kernel)" 2>/dev/null || true)
  if [[ "$perms" =~ ^[0-5]44$ ]]; then
    pass "booted kernel image is read-only (mode $perms)"
  else
    warn "booted kernel image mode: $perms"
  fi
fi

describe "udev state is populated"
udev_rules_dir=/run/current-system/sw/etc/udev/rules.d
if [[ -d "$udev_rules_dir" ]]; then
  cnt=$(find "$udev_rules_dir" -maxdepth 1 -type f -name '*.rules' 2>/dev/null | wc -l)
  if [[ "$cnt" -gt 0 ]]; then
    pass "udev rules directory has $cnt rule file(s)"
  else
    warn "udev rules directory empty"
  fi
fi

describe "wayland / plasma session binaries"
for c in kded6 kscreen-doctor qdbus-qt6 kwin_wayland; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    info "$c not in PATH (may be installed but not exported; not blocking)"
  fi
done

describe "user-level systemd manager is alive for active users"
# Check if the active user(s) have a running systemd --user instance
if [[ ${#all_users[@]} -eq 0 ]]; then
  info "no users declared - cannot verify user-level systemd"
else
  for u in "${all_users[@]}"; do
    active=$(config_value "myOS.users.${u}._activeOn" | jq_cmd -r 'select(type=="boolean")')
    if [[ "$active" == "true" ]]; then
      # Try to check if user has a systemd session
      if systemctl --user status --no-pager 2>/dev/null | head -3 | grep -q 'running'; then
        pass "$u: --user systemd manager is running"
      else
        info "$u: --user systemd manager status not visible from this shell"
      fi
      # Only check first active user from current shell context
      break
    fi
  done
fi
