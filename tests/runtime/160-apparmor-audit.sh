#!/usr/bin/env bash
# Runtime: AppArmor + auditd posture per profile.
source "${BASH_SOURCE%/*}/../lib/common.sh"

profile=$(detect_profile)

describe "AppArmor (on both profiles)"
assert_service_active apparmor.service
# D-Bus must report apparmor=required
if grep -Rq 'apparmor' /etc/dbus-1/system.d 2>/dev/null \
   || [[ -r /etc/dbus-1/system.conf ]] && grep -q 'apparmor' /etc/dbus-1/system.conf 2>/dev/null; then
  pass "D-Bus AppArmor mediation wired"
else
  warn "D-Bus AppArmor mediation not obviously wired; NixOS may inject it via /nix/store"
fi
if command -v aa-status >/dev/null 2>&1; then
  # aa-status requires root
  if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
    prof_count=$(sudo -n aa-status --enforced 2>/dev/null | wc -l)
    if [[ "$prof_count" -ge 1 ]]; then
      pass "aa-status reports $prof_count enforced profile(s)"
    else
      warn "aa-status reports 0 enforced profiles (framework only, no custom library)"
    fi
  else
    info "aa-status requires sudo"
  fi
else
  warn "aa-status not in PATH"
fi

describe "auditd state per profile"
if [[ "$profile" == "paranoid" ]]; then
  assert_service_active auditd.service
  if command -v auditctl >/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
      if sudo -n auditctl -s 2>/dev/null | grep -qE 'enabled 1'; then
        pass "auditctl -s: audit subsystem enabled"
      else
        fail "auditctl -s did not report 'enabled 1'"
      fi
    else
      info "auditctl -s requires sudo"
    fi
  else
    warn "auditctl not in PATH"
  fi
  # Repo custom audit rules are staged off → audit-rules-nixos.service may exist
  # but should have empty or default rule set. The `audit-rules-nixos.service`
  # unit is added by NixOS regardless; its state is acceptable either way.
  if systemctl cat audit-rules-nixos.service >/dev/null 2>&1; then
    info "audit-rules-nixos.service unit present"
  fi
else
  # daily: auditd explicitly off
  if systemctl is-active --quiet auditd.service 2>/dev/null; then
    fail "daily: auditd.service is active but should be off"
  else
    pass "daily: auditd.service inactive"
  fi
fi

describe "coredumps disabled (systemd.coredump.extraConfig Storage=none)"
cfg=/etc/systemd/coredump.conf
if [[ -r $cfg ]]; then
  if grep -qE '^\s*Storage\s*=\s*none' "$cfg"; then
    pass "coredump storage=none"
  else
    fail "Storage=none not found in coredump.conf"
  fi
  if grep -qE '^\s*ProcessSizeMax\s*=\s*0' "$cfg"; then
    pass "coredump ProcessSizeMax=0"
  else
    fail "ProcessSizeMax=0 not found in coredump.conf"
  fi
fi

describe "journald size limits"
jconf=/etc/systemd/journald.conf
if [[ -r $jconf ]]; then
  for k in 'RuntimeMaxUse=250M' 'SystemMaxUse=250M' 'SystemKeepFree=1G'; do
    if grep -q "$k" "$jconf"; then
      pass "journald: $k"
    else
      fail "journald missing $k"
    fi
  done
fi
