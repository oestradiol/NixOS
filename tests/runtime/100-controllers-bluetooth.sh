#!/usr/bin/env bash
# Runtime: Bluetooth + controller plumbing (daily only).
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_profile daily

describe "bluetooth stack"
# bluetooth.service should be active if a bluetooth adapter is present
if systemctl is-active --quiet bluetooth.service; then
  pass "service active: bluetooth.service"
else
  fail "service active: bluetooth.service" "state: $(systemctl is-active bluetooth.service 2>&1 || true)"
fi
if systemctl is-enabled --quiet bluetooth.service; then
  pass "unit enabled: bluetooth.service (enabled)"
else
  fail "unit enabled: bluetooth.service" "state: $(systemctl is-enabled bluetooth.service 2>&1 || true)"
fi
# blueman-mechanism.service may be inactive if no bluetooth hardware
if systemctl is-active --quiet blueman-mechanism.service; then
  pass "service active: blueman-mechanism.service"
else
  warn "service active: blueman-mechanism.service" "state: $(systemctl is-active blueman-mechanism.service 2>&1 || true) (may be inactive without hardware)"
fi

describe "bluetooth modules + config"
assert_module_loaded bluetooth
# disable_ertm=1 must have propagated through modprobe.d
found_ertm=0
while IFS= read -r f; do
  if grep -Fq 'disable_ertm=1' "$f" 2>/dev/null; then
    found_ertm=1
    break
  fi
done < <(find /etc/modprobe.d /run/current-system/etc/modprobe.d -maxdepth 2 -type f 2>/dev/null || true)
if [[ $found_ertm -eq 1 ]]; then
  pass "bluetooth disable_ertm=1 found in modprobe config"
else
  warn "bluetooth disable_ertm=1 missing from modprobe.d (may not be applied if rebuild switched to toplevel)"
fi

describe "xpadneo (Xbox wireless BT driver) built"
# xpadneo.enable = true → hwdb + dkms-built module. The module may not be
# loaded until a controller connects. Accept either loaded or installed.
if lsmod | awk '{print $1}' | grep -Fxq hid_xpadneo; then
  pass "hid_xpadneo module is loaded"
else
  # Look for the module under /run/current-system/kernel-modules or /lib/modules
  kmod_dir=$(find /run/current-system/kernel-modules -type d -name xpadneo 2>/dev/null | head -1)
  if [[ -n "$kmod_dir" ]]; then
    pass "hid_xpadneo present on disk (not loaded; will auto-load when controller connects)"
  else
    warn "hid_xpadneo not found in current kernel modules tree"
  fi
fi

describe "udev rules for controllers"
rules_dir=/run/current-system/sw/etc/udev/rules.d
if [[ -d $rules_dir ]]; then
  # game-devices-udev-rules provides many rule files
  if find "$rules_dir" -type f -name '*.rules' -exec grep -lF 'idVendor=="045e"' {} + 2>/dev/null | grep -q .; then
    pass "Xbox vendor udev rules present"
  else
    warn "Xbox vendor udev rules not found (may be in /run/current-system/etc/udev/rules.d instead)"
  fi
fi
# Check the extraRules lines inlined by repo.
if [[ -r /etc/udev/rules.d/99-local.rules ]] \
   || find /run/current-system -name 'udev-rules' 2>/dev/null | xargs -r grep -lq 'static_node=uinput' 2>/dev/null; then
  pass "uinput static_node udev rule present"
else
  warn "could not verify uinput static_node udev rule location"
fi

describe "input group + /dev/uinput"
if getent group input >/dev/null; then pass "input group exists"; else fail "input group missing"; fi
if [[ -c /dev/uinput ]]; then
  pass "/dev/uinput exists"
else
  warn "/dev/uinput not present (may appear only when uinput module loads)"
fi

describe "player is in input/render/audio/video groups"
for g in input render audio video networkmanager; do
  if id -nG player | grep -qw "$g"; then
    pass "player in $g"
  else
    fail "player missing from $g group"
  fi
done
