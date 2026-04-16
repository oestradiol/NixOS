#!/usr/bin/env bash
# Static: confirm that the daily specialisation actually softens the expected
# controls versus the paranoid baseline. Every delta mapped here appears in
# `docs/maps/HARDENING-TRACKER.md` and `docs/maps/SECURITY-SURFACES.md`.
# If one of them starts matching paranoid, paranoid/daily is collapsing.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

# Helper: eval on both configs, assert exact JSON mismatch/match.
ep() { nix_eval "$1"; }
ed() { nix_eval_daily "$1"; }

eq() {
  # eq <attr> <expect-paranoid-json> <expect-daily-json> <label>
  local p d want_p="$2" want_d="$3" label="$4"
  p=$(ep "$1"); d=$(ed "$1")
  if [[ "$p" == "$want_p" && "$d" == "$want_d" ]]; then
    pass "$label"
  else
    fail "$label" "paranoid: $p" "daily:    $d" "wanted paranoid: $want_p" "wanted daily:    $want_d"
  fi
}

describe "sandbox posture delta"
eq 'myOS.security.sandbox.browsers' 'true'  'false' "sandbox.browsers: paranoid=true, daily=false"
eq 'myOS.security.sandbox.apps'     'false' 'true'  "sandbox.apps:     paranoid=false, daily=true"
eq 'myOS.security.sandbox.vms'      'true'  'false' "sandbox.vms:      paranoid=true, daily=false"
eq 'myOS.security.sandbox.x11'      'false' 'true'  "sandbox.x11:      paranoid=false, daily=true"
eq 'myOS.security.sandbox.wayland'  'true'  'true'  "sandbox.wayland:  both=true"
eq 'myOS.security.sandbox.pipewire' 'true'  'true'  "sandbox.pipewire: both=true"
eq 'myOS.security.sandbox.gpu'      'true'  'true'  "sandbox.gpu:      both=true"
eq 'myOS.security.sandbox.portals'  'true'  'true'  "sandbox.portals:  both=true"
eq 'myOS.security.sandbox.dbusFilter' 'true' 'true' "sandbox.dbusFilter: both=true"

describe "kernel posture delta"
eq 'myOS.security.disableSMT' 'true' 'false' "disableSMT: paranoid=true, daily=false"
eq 'myOS.security.usbRestrict' 'true' 'false' "usbRestrict: paranoid=true, daily=false"
eq 'myOS.security.auditd' 'true' 'false' "auditd: paranoid=true, daily=false"
eq 'myOS.security.ptraceScope' '2' '1' "ptraceScope: paranoid=2, daily=1"
eq 'myOS.security.kernelHardening.initOnFree' 'true' 'false' "initOnFree: paranoid=true, daily=false"
eq 'myOS.security.kernelHardening.disableIcmpEcho' 'true' 'false' "disableIcmpEcho: paranoid=true, daily=false"
eq 'myOS.security.kernelHardening.ioUring' '2' '1' "ioUring: paranoid=2, daily=1"

describe "memory / swap posture"
eq 'myOS.security.swappiness' '180' '150' "swappiness: paranoid=180, daily=150"
eq 'myOS.security.hardenedMemory.enable' 'false' 'false' "hardenedMemory off on both (staged)"

describe "profile-invariant shared base"
eq 'myOS.security.impermanence.enable' 'true' 'true' "impermanence on both"
eq 'myOS.security.agenix.enable'       'true' 'true' "agenix on both"
eq 'myOS.security.apparmor'            'true' 'true' "apparmor on both"
eq 'myOS.security.lockRoot'            'true' 'true' "lockRoot on both"
eq 'myOS.security.persistMachineId'    'true' 'true' "persistMachineId on both"
eq 'myOS.security.allowSleep'          'false' 'false' "allowSleep off on both"

describe "staged features off on both"
eq 'myOS.security.secureBoot.enable' 'false' 'false' "secureBoot staged off"
eq 'myOS.security.tpm.enable'        'false' 'false' "tpm staged off"
eq 'myOS.security.wireguardMullvad.enable' 'false' 'false' "self-owned WG staged off"
eq 'myOS.security.auditRules.enable' 'false' 'false' "audit rules staged off"
eq 'myOS.security.kernelHardening.oopsPanic'       'false' 'false' "oops=panic staged off"
eq 'myOS.security.kernelHardening.moduleSigEnforce' 'false' 'false' "module.sig_enforce staged off"
eq 'myOS.security.kernelHardening.modulesDisabled' 'false' 'false' "modules_disabled staged off"
eq 'myOS.security.pamProfileBinding.enable' 'false' 'false' "PAM profile-binding rejected/off"

describe "gaming / desktop delta"
eq 'myOS.gaming.controllers.enable' 'false' 'true' "controllers: paranoid=false, daily=true"
eq 'programs.steam.enable' 'false' 'true' "Steam: paranoid=false, daily=true"
eq 'programs.gamescope.enable' 'false' 'true' "gamescope: paranoid=false, daily=true"
eq 'programs.gamemode.enable' 'false' 'true' "gamemode: paranoid=false, daily=true"
eq 'services.wivrn.enable' 'false' 'true' "wivrn: paranoid=false, daily=true"

describe "networking delta"
eq 'services.mullvad-vpn.enable' 'false' 'true' "mullvad daemon: paranoid=false, daily=true"
eq 'networking.firewall.enable' 'true' 'true' "firewall on both (app-mode)"

describe "browsers: paranoid uses wrappers, daily uses system firefox"
# On paranoid sandbox.browsers=true → programs.firefox.enable would be false (wrappers provide it).
# On daily sandbox.browsers=false → programs.firefox.enable=true.
eq 'programs.firefox.enable' 'false' 'true' "firefox program: paranoid=false, daily=true"
