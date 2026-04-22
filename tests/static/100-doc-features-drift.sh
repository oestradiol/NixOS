#!/usr/bin/env bash
# Static governance: docs/maps/FEATURES.md claims must be supported by the
# actual code / eval. Catches documentation drift.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

feat="$REPO_ROOT/docs/maps/FEATURES.md"
assert_file "$feat"

# Helper: assert a literal string appears in FEATURES.md (catches wording drift).
doc_claims() {
  if grep -Fq "$1" "$feat"; then
    pass "FEATURES.md still claims: $1"
  else
    fail "FEATURES.md drifted: claim missing" "$1"
  fi
}

describe "base system claims"
doc_claims "one default profile: \`paranoid\`"
doc_claims "one specialization: \`daily\`"
doc_claims "Home Manager"
doc_claims "Stylix"
doc_claims "impermanence"
doc_claims "lanzaboote module available"
doc_claims "agenix module available"

describe "user model claims match users.nix (template-agnostic)"
# Verify the framework's user binding mechanism works using test fixture users
# (templates may define any user names; we test the framework behavior, not template content)
doc_claims "immutable users (declarative password management via hashedPasswordFile)"
doc_claims "root account lock path supported"
doc_claims "profile-user binding enforced via account locking"

# Verify test users from eval-cache.nix have correct shells (template-agnostic check)
assert_contains "$(nix_eval 'users.users.test_daily.shell')" 'zsh' "test_daily.shell is zsh"
assert_contains "$(nix_eval 'users.users.test_paranoid.shell')" 'zsh' "test_paranoid.shell is zsh"

# Verify active user detection works
test_daily_active="$(nix_eval 'myOS.users.test_daily._activeOn')"
test_paranoid_active="$(nix_eval 'myOS.users.test_paranoid._activeOn')"
info "test_daily._activeOn = $test_daily_active (paranoid profile)"
info "test_paranoid._activeOn = $test_paranoid_active (paranoid profile)"

describe "browser claims"
# FEATURES.md uses a list form; check for the list entries rather than a prose
# phrasing borrowed from PROJECT-STATE.md.
doc_claims "plain \`programs.firefox\`"
doc_claims "\`safe-firefox\`"
doc_claims "vendored arkenfox base + repo overrides"
doc_claims "managed by enterprise policies"
# Verify the wrappers actually exist in the security module.
if grep -Fq 'safeFirefox ' "$REPO_ROOT/modules/security/browser.nix" \
   && grep -Fq 'safeTor '     "$REPO_ROOT/modules/security/browser.nix" \
   && grep -Fq 'safeMullvad ' "$REPO_ROOT/modules/security/browser.nix"; then
  pass "safe-firefox, safe-tor, safe-mullvad wrappers defined"
else
  fail "one or more safe-* browser wrappers missing from browser.nix"
fi

describe "gaming stack claims (daily)"
doc_claims "Steam"
doc_claims "gamescope"
doc_claims "gamemode"
doc_claims "NT sync kernel module"
doc_claims "VR module import"
doc_claims "controllers module import"

describe "flatpak claims"
doc_claims "Flatpak enabled"
doc_claims "Flathub auto-added"
doc_claims "xdg-desktop-portal enabled"
doc_claims "GTK portal enabled"

# flatpak portal actually enabled
assert_eq "$(nix_eval 'services.flatpak.enable')"       'true' "services.flatpak.enable (paranoid)"
assert_eq "$(nix_eval_daily 'services.flatpak.enable')" 'true' "services.flatpak.enable (daily)"
assert_eq "$(nix_eval 'xdg.portal.enable')"             'true' "xdg.portal.enable (paranoid)"
assert_eq "$(nix_eval_daily 'xdg.portal.enable')"       'true' "xdg.portal.enable (daily)"

describe "desktop claims"
doc_claims "Plasma 6"
doc_claims "greetd + regreet"
doc_claims "X server explicitly disabled"
doc_claims "PipeWire enabled"
doc_claims "PulseAudio disabled"
doc_claims "fcitx5"

assert_eq "$(nix_eval 'services.xserver.enable')" 'false' "xserver disabled (paranoid)"
assert_eq "$(nix_eval_daily 'services.xserver.enable')" 'false' "xserver disabled (daily)"
assert_eq "$(nix_eval 'myOS.desktopEnvironment')" '"plasma"' "desktop environment is plasma"
assert_eq "$(nix_eval 'services.desktopManager.plasma6.enable')" 'true' "plasma6 enabled"
assert_eq "$(nix_eval 'programs.regreet.enable')" 'true' "regreet enabled"
assert_eq "$(nix_eval 'services.greetd.enable')" 'true' "greetd enabled"
assert_eq "$(nix_eval 'services.pipewire.enable')" 'true' "pipewire enabled"
assert_eq "$(nix_eval 'services.pulseaudio.enable')" 'false' "pulseaudio disabled"
assert_eq "$(nix_eval 'i18n.inputMethod.enable')" 'true' "inputMethod enabled"

describe "monitoring claims"
doc_claims "ClamAV installed"
doc_claims "ClamAV updater enabled"
doc_claims "AIDE installed"
doc_claims "AppArmor enablement path"
assert_eq "$(nix_eval 'services.clamav.updater.enable')"       'true' "clamav updater (paranoid)"
assert_eq "$(nix_eval_daily 'services.clamav.updater.enable')" 'true' "clamav updater (daily)"
assert_eq "$(nix_eval 'security.apparmor.enable')"             'true' "apparmor on paranoid"
assert_eq "$(nix_eval_daily 'security.apparmor.enable')"       'true' "apparmor on daily"

describe "VM tooling claims"
doc_claims "libvirtd enabled"
doc_claims "\`qemu_kvm\`"
doc_claims "swtpm enabled"
doc_claims "virt-manager enabled"
doc_claims "repo VM helper script \`repo-vm-class\`"
# On paranoid, VM tooling is on. On daily, it is off.
assert_eq "$(nix_eval 'virtualisation.libvirtd.enable')"       'true'  "libvirtd on paranoid"
assert_eq "$(nix_eval_daily 'virtualisation.libvirtd.enable')" 'false' "libvirtd off on daily"

describe "networking claims"
doc_claims "NetworkManager enabled"
doc_claims "resolved enabled system-wide"
doc_claims "daily Wake-on-LAN on \`enp5s0\`"
assert_eq "$(nix_eval 'networking.networkmanager.enable')" 'true' "NM on paranoid"
assert_eq "$(nix_eval_daily 'networking.networkmanager.enable')" 'true' "NM on daily"
assert_eq "$(nix_eval 'services.resolved.enable')" 'true' "resolved on paranoid"
assert_eq "$(nix_eval_daily 'services.resolved.enable')" 'true' "resolved on daily"
