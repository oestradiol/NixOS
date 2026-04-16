#!/usr/bin/env bash
# Runtime: systemd-boot entries, loader.conf, expected generations + daily
# entry. Lanzaboote must not be active.
source "${BASH_SOURCE%/*}/../lib/common.sh"

needs_sudo

describe "systemd-boot is the active bootloader (not lanzaboote)"
if [[ "$(id -u)" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  skip "bootctl status / /boot/loader inspection needs sudo"
  # Continue with non-privileged fallbacks below.
else
  if sudo -n bootctl is-installed 2>/dev/null | grep -q 'yes'; then
    pass "bootctl is-installed = yes"
  else
    fail "bootctl is-installed != yes" "$(sudo -n bootctl is-installed 2>&1 || true)"
  fi
  if sudo -n bootctl status 2>/dev/null | grep -q 'systemd-boot'; then
    pass "systemd-boot reported by bootctl"
  else
    warn "systemd-boot string not found in bootctl status"
  fi
fi

describe "/boot/loader/entries contains expected NixOS entries"
if ! sudo -n test -d /boot/loader/entries 2>/dev/null; then
  skip "/boot/loader/entries requires sudo (vfat fmask=0077)"
else
  entries=$(sudo -n ls /boot/loader/entries 2>/dev/null || true)
  # Must have at least one `nixos-generation-*.conf`
  if grep -qE '^nixos-generation-[0-9]+\.conf$' <<<"$entries"; then
    pass "primary NixOS entry(ies) exist"
  else
    fail "no nixos-generation-*.conf files" "$entries"
  fi
  # Must have at least one daily-specialisation entry.
  if grep -qE '^nixos-generation-[0-9]+-specialisation-daily\.conf$' <<<"$entries"; then
    pass "daily specialisation entry(ies) exist"
  else
    fail "no nixos-generation-*-specialisation-daily.conf files" "$entries"
  fi
  info "entries sample: $(printf '%s' "$entries" | head -5 | tr '\n' ' ')"
else
  fail "/boot/loader/entries not readable"
fi

describe "/boot/loader/loader.conf"
if ! sudo -n test -r /boot/loader/loader.conf 2>/dev/null; then
  skip "/boot/loader/loader.conf requires sudo"
else
  cfg=$(sudo -n cat /boot/loader/loader.conf)
  if grep -qE '^timeout' <<<"$cfg"; then
    pass "timeout directive present"
  else
    fail "timeout directive missing"
  fi
  if grep -qE '^default' <<<"$cfg"; then
    def=$(awk '/^default /{print $2}' <<<"$cfg")
    pass "default entry = $def"
    info "full loader.conf: $(printf '%s' "$cfg" | tr '\n' '|')"
  else
    warn "no default directive in loader.conf — last boot order will be whatever systemd-boot picks"
  fi
else
  fail "/boot/loader/loader.conf not readable"
fi

describe "EFI variable access permitted (efi.canTouchEfiVariables=true)"
if [[ -d /sys/firmware/efi/efivars ]]; then
  pass "efivars dir present"
else
  fail "efivars dir missing (not booted in UEFI mode?)"
fi

describe "lanzaboote staged off"
# With SB off, lanzaboote.nix is not imported into the live config; its
# artefacts must not be in /boot.
if ! sudo -n true 2>/dev/null; then
  skip "lanzaboote artefact check needs sudo"
else
  if sudo -n test -d /boot/EFI/Linux 2>/dev/null \
     && sudo -n ls /boot/EFI/Linux 2>/dev/null | grep -q '\.efi$'; then
    fail "lanzaboote UKI dir populated but SB is staged off"
  else
    pass "no lanzaboote UKI artefacts in /boot/EFI/Linux"
  fi
fi
