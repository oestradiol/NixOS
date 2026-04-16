#!/usr/bin/env bash
# Runtime: audio + input method. PipeWire stack (ALSA, Pulse compat, JACK,
# WirePlumber), RTKit, fcitx5.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "PipeWire stack system-level socket activation"
# PipeWire is a user service — system-level it's usually just the socket
# facility. Accept either system-level or user-level activation.
if systemctl is-active --quiet pipewire.socket 2>/dev/null \
   || systemctl --user is-active --quiet pipewire.socket 2>/dev/null \
   || systemctl --user is-active --quiet pipewire.service 2>/dev/null; then
  pass "pipewire socket/service active"
else
  warn "pipewire is not reported active at system or user level"
fi

describe "WirePlumber session manager"
if systemctl --user is-active --quiet wireplumber.service 2>/dev/null \
   || systemctl is-active --quiet wireplumber.service 2>/dev/null; then
  pass "wireplumber active"
else
  warn "wireplumber not reported active"
fi

describe "RTKit"
assert_service_active rtkit-daemon.service

describe "PulseAudio daemon NOT present"
if systemctl --user is-active --quiet pulseaudio.service 2>/dev/null; then
  fail "pulseaudio user service is active (should be disabled)"
else
  pass "pulseaudio user service inactive"
fi
if systemctl is-active --quiet pulseaudio.service 2>/dev/null; then
  fail "pulseaudio system service is active"
else
  pass "pulseaudio system service inactive"
fi

describe "ALSA + 32-bit ALSA support binaries"
for c in aplay arecord; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c in PATH"
  else
    warn "$c not in PATH"
  fi
done
if command -v pw-cli >/dev/null 2>&1; then
  pass "pw-cli (pipewire CLI) in PATH"
fi

describe "JACK compatibility path"
if command -v jack_control >/dev/null 2>&1 || command -v pw-jack >/dev/null 2>&1; then
  pass "JACK-compatible binary present"
else
  warn "no JACK binary in PATH (service could still be enabled via PW jack=true)"
fi

describe "fcitx5 configuration exists"
# The system enables i18n.inputMethod via fcitx5. Configuration dir must exist
# somewhere in /nix/store linked through /etc or user config.
if command -v fcitx5 >/dev/null 2>&1; then
  pass "fcitx5 in PATH"
else
  fail "fcitx5 missing from PATH"
fi
# Mozc addon present.
if /run/current-system/sw/bin/fcitx5 --help-addons 2>/dev/null | grep -qi mozc \
   || find /nix/store -maxdepth 3 -name 'mozc.conf' 2>/dev/null | grep -q .; then
  pass "mozc (fcitx5-mozc-ut) addon present"
else
  warn "fcitx5-mozc-ut not obviously installed"
fi

describe "XKB_DEFAULT_LAYOUT for Wayland-native keyboard"
# Set in environment.sessionVariables; should be exported by systemd at login.
if [[ "${XKB_DEFAULT_LAYOUT:-}" == "br" ]]; then
  pass "XKB_DEFAULT_LAYOUT = br in current session"
else
  # Also check /etc/profile.d or systemd user environment.
  if grep -Rq 'XKB_DEFAULT_LAYOUT.*br' /etc/profile.d/ 2>/dev/null \
     || grep -Rq 'XKB_DEFAULT_LAYOUT.*br' /etc/systemd/system-environment-generators/ 2>/dev/null; then
    pass "XKB_DEFAULT_LAYOUT is set to br (system-level)"
  else
    warn "XKB_DEFAULT_LAYOUT not observable in this session"
  fi
fi
