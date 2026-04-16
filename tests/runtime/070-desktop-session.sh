#!/usr/bin/env bash
# Runtime: desktop session. greetd, Plasma 6, Wayland-only, polkit, udisks,
# printing/openssh disabled, fwupd, gpg-agent.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "display manager stack"
assert_service_active greetd.service
assert_unit_enabled   greetd.service
assert_service_active polkit.service
assert_service_active dbus.service
assert_service_active systemd-udevd.service

describe "udisks + fwupd + openssh/printing expectations"
assert_service_active udisks2.service
# fwupd is d-bus activated — no socket unit, and the service is inactive
# until a client talks to it over D-Bus. Presence of the unit is the
# strongest assertion we can make without a firmware operation.
if systemctl cat fwupd.service >/dev/null 2>&1; then
  pass "fwupd.service unit is defined (d-bus activated)"
  state=$(systemctl is-active fwupd.service 2>&1 || true)
  info "fwupd state: $state (inactive until first D-Bus call)"
else
  fail "fwupd.service unit missing"
fi
# openssh disabled.
if systemctl is-active --quiet sshd.service 2>/dev/null; then
  fail "sshd.service is active but should be disabled"
else
  pass "sshd.service inactive (openssh disabled)"
fi
# printing disabled.
if systemctl is-active --quiet cups.service 2>/dev/null; then
  fail "cups.service is active but printing should be disabled"
else
  pass "cups.service inactive (printing disabled)"
fi

describe "Xorg is NOT running (Wayland-only)"
if pgrep -x Xorg >/dev/null 2>&1 || pgrep -x Xwayland >/dev/null 2>&1; then
  # Xwayland is acceptable as it is launched on demand by Plasma; check Xorg only.
  if pgrep -x Xorg >/dev/null 2>&1; then
    fail "Xorg process is running"
  else
    pass "Xorg not running (Xwayland on demand is allowed)"
  fi
else
  pass "no Xorg/Xwayland currently active"
fi

describe "Wayland runtime socket present when a user session exists"
# $XDG_RUNTIME_DIR is per-user; if running as a normal user in a graphical
# session, at least one wayland-N socket should exist.
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
  socks=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null | wc -l)
  if [[ "$socks" -gt 0 ]]; then
    pass "wayland socket present ($socks) in $XDG_RUNTIME_DIR"
  else
    warn "no wayland socket in $XDG_RUNTIME_DIR (not in a desktop session?)"
  fi
else
  skip "XDG_RUNTIME_DIR not set (probably not a user session)"
fi

describe "Plasma 6 via packages + /run/current-system"
# The repo enables services.desktopManager.plasma6.enable = true.
# Verify kwin or plasmashell show up in PATH.
if command -v plasmashell >/dev/null 2>&1; then
  pass "plasmashell is in PATH"
else
  fail "plasmashell not found in PATH"
fi
if command -v kwin_wayland >/dev/null 2>&1; then
  pass "kwin_wayland is in PATH"
else
  fail "kwin_wayland not found in PATH"
fi

describe "regreet + greetd"
# greetd + regreet are launched by systemd; their binaries live under
# /nix/store and do not need to be in the interactive login PATH.
es=$(systemctl cat greetd.service 2>/dev/null | awk -F= '/^ExecStart=/{print $2; exit}')
if [[ -n "$es" && -x "${es%% *}" ]]; then
  pass "greetd.service ExecStart points at an executable (${es%% *})"
else
  fail "greetd.service ExecStart is invalid" "$es"
fi
# regreet has its own .toml + .css under /etc/greetd (NOT config.toml).
assert_file /etc/greetd/regreet.toml
assert_file /etc/greetd/regreet.css

describe "GnuPG agent + SSH support"
if command -v gpg-agent >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1; then
  pass "gpg and gpg-agent in PATH"
else
  fail "gpg/gpg-agent missing from PATH"
fi
# pinentry-qt is pulled in via programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt.
# It ends up installed via the gpg-agent wrapper but may not be in the
# interactive PATH. Verify by scanning /nix/store for the binary.
# Note: /nix/store dir names are <hash>-<name>-<version>, so the glob must
# start with `*` to match the name portion.
if command -v pinentry-qt >/dev/null 2>&1 \
   || find /nix/store -maxdepth 2 -type d -name '*-pinentry-qt-*' 2>/dev/null | grep -q . \
   || find /nix/store -maxdepth 3 -type f -name 'pinentry-qt' 2>/dev/null | grep -q .; then
  pass "pinentry-qt present on disk"
else
  fail "pinentry-qt not found in PATH or /nix/store"
fi

describe "keymap + locale"
assert_file /etc/vconsole.conf
if grep -Fq 'br-abnt2' /etc/vconsole.conf 2>/dev/null; then
  pass "console keymap = br-abnt2"
else
  warn "console keymap not br-abnt2"
fi
# locale.conf check
if [[ -r /etc/locale.conf ]]; then
  if grep -Fq 'LANG=en_GB.UTF-8' /etc/locale.conf; then
    pass "LANG = en_GB.UTF-8"
  else
    warn "LANG drift"
  fi
fi
