#!/usr/bin/env bash
# Static: the myOS.debug knob namespace exists, defaults off, and gates the
# correct downstream surfaces.
#
# Default-state checks use the cached paranoid+daily eval. Active-state
# checks run targeted `nix eval` calls with overrides because the cache
# only captures the default configuration.
source "${BASH_SOURCE%/*}/../lib/common.sh"

require_cmd nix || exit 0
_tc_ensure_jq || { skip "jq unavailable"; exit 0; }

describe "debug option namespace is declared"
assert_eq "$(nix_eval 'myOS.debug.enable')"                   'false' "debug.enable defaults false (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.debug.enable')"             'false' "debug.enable defaults false (daily)"
assert_eq "$(nix_eval 'myOS.debug.crossProfileLogin.enable')" 'false' "crossProfileLogin defaults false (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.debug.crossProfileLogin.enable')" 'false' "crossProfileLogin defaults false (daily)"
assert_eq "$(nix_eval 'myOS.debug.paranoidWheel.enable')"     'false' "paranoidWheel defaults false (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.debug.paranoidWheel.enable')" 'false' "paranoidWheel defaults false (daily)"
assert_eq "$(nix_eval 'myOS.debug.warnings.enable')"          'true'  "warnings defaults true (paranoid)"
assert_eq "$(nix_eval_daily 'myOS.debug.warnings.enable')"    'true'  "warnings defaults true (daily)"

describe "default state preserves the current profile-user binding"
# Test fixture users: test_paranoid (active on paranoid), test_daily (active on daily)
# These are synthetic test users defined in tests/lib/eval-cache.nix for testing framework behavior.

# Paranoid profile: test_paranoid active, test_daily locked
assert_eq "$(nix_eval 'users.users.test_daily.hashedPasswordFile')" 'null' \
  "paranoid: test_daily.hashedPasswordFile is null (locked)"
pw=$(nix_eval 'users.users.test_daily.hashedPassword')
assert_eq "$pw" '"!"' "paranoid: test_daily.hashedPassword = \"!\" (locked)"
paranoid_pwf=$(nix_eval 'users.users.test_paranoid.hashedPasswordFile')
assert_eq "$paranoid_pwf" '"/persist/secrets/test_paranoid-password.hash"' \
  "paranoid: test_paranoid.hashedPasswordFile points at test_paranoid-password.hash"
paranoid_pw=$(nix_eval 'users.users.test_paranoid.hashedPassword')
assert_eq "$paranoid_pw" 'null' "paranoid: test_paranoid.hashedPassword is null (unlocked)"

# Daily profile: test_daily active, test_paranoid locked
assert_eq "$(nix_eval_daily 'users.users.test_paranoid.hashedPasswordFile')" 'null' \
  "daily: test_paranoid.hashedPasswordFile is null (locked)"
paranoid_pw_d=$(nix_eval_daily 'users.users.test_paranoid.hashedPassword')
assert_eq "$paranoid_pw_d" '"!"' "daily: test_paranoid.hashedPassword = \"!\" (locked)"
daily_pwf=$(nix_eval_daily 'users.users.test_daily.hashedPasswordFile')
assert_eq "$daily_pwf" '"/persist/secrets/test_daily-password.hash"' \
  "daily: test_daily.hashedPasswordFile points at test_daily-password.hash"
daily_pw_d=$(nix_eval_daily 'users.users.test_daily.hashedPassword')
assert_eq "$daily_pw_d" 'null' "daily: test_daily.hashedPassword is null (unlocked)"

describe "default state: test_paranoid is NOT in wheel on paranoid (allowWheel=false)"
paranoid_groups=$(nix_eval 'users.users.test_paranoid.extraGroups')
if jq_cmd -e '. | index("wheel")' <<<"$paranoid_groups" >/dev/null 2>&1; then
  fail "default paranoid eval: test_paranoid has 'wheel' in extraGroups" "$paranoid_groups"
else
  pass "default paranoid eval: test_paranoid does NOT have 'wheel' in extraGroups"
fi

# ── Active-state (debug.enable=true) checks ───────────────────────────────
# These use targeted nix evals with module overrides. No caching — keep count small.

_debug_eval() {
  local attr="$1" extraModule="$2"
  local nix_expr
debug_eval_nix_expr() {
cat <<'NIXEOF'
let
  flake = builtins.getFlake "REPO_ROOT";
  nixpkgs = flake.inputs.nixpkgs;
  agenix = flake.inputs.agenix;
  impermanence = flake.inputs.impermanence;
  lanzaboote = flake.inputs.lanzaboote;
  home-manager = flake.inputs.home-manager;
  stylix = flake.inputs.stylix;
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  hardening = flake.outputs.nixosModules;
  baseModules = [
    { nixpkgs.config.allowUnfree = true;
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = nixpkgs.lib.mkForce false;
      boot.kernelModules = [ "kvm-amd" ];
      myOS.users.test_daily = { activeOnProfiles = [ "daily" ]; description = "Test Daily"; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = true; home.persistent = true; };
      myOS.users.test_paranoid = { activeOnProfiles = [ "paranoid" ]; description = "Test Paranoid"; uid = 1001; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = false; home.persistent = false; };
    }
    agenix.nixosModules.default
    impermanence.nixosModules.impermanence
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager
    stylix.nixosModules.stylix
    hardening.default hardening.profile-paranoid
    (EXTRA_MODULE)
  ];
  result = nixpkgs.lib.nixosSystem { inherit system; modules = baseModules; };
in result.config.ATTR_PATH
NIXEOF
}
  nix_expr=$(debug_eval_nix_expr)
  nix_expr=${nix_expr//REPO_ROOT/$REPO_ROOT}
  nix_expr=${nix_expr//ATTR_PATH/$attr}
  nix_expr=${nix_expr//EXTRA_MODULE/$extraModule}
  nix --extra-experimental-features 'nix-command flakes' eval --impure --json --no-write-lock-file --expr "$nix_expr" 2>/dev/null
}

_debug_eval_daily() {
  local attr="$1" extraModule="$2"
  local nix_expr
debug_eval_daily_nix_expr() {
cat <<'NIXEOF'
let
  flake = builtins.getFlake "REPO_ROOT";
  nixpkgs = flake.inputs.nixpkgs;
  agenix = flake.inputs.agenix;
  impermanence = flake.inputs.impermanence;
  lanzaboote = flake.inputs.lanzaboote;
  home-manager = flake.inputs.home-manager;
  stylix = flake.inputs.stylix;
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  hardening = flake.outputs.nixosModules;
  baseModules = [
    { nixpkgs.config.allowUnfree = true;
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = nixpkgs.lib.mkForce false;
      boot.kernelModules = [ "kvm-amd" ];
      myOS.users.test_daily = { activeOnProfiles = [ "daily" ]; description = "Test Daily"; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = true; home.persistent = true; };
      myOS.users.test_paranoid = { activeOnProfiles = [ "paranoid" ]; description = "Test Paranoid"; uid = 1001; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = false; home.persistent = false; };
    }
    agenix.nixosModules.default
    impermanence.nixosModules.impermanence
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager
    stylix.nixosModules.stylix
    hardening.default hardening.profile-paranoid hardening.profile-daily
    (EXTRA_MODULE)
  ];
  result = nixpkgs.lib.nixosSystem { inherit system; modules = baseModules; };
in result.config.ATTR_PATH
NIXEOF
}
  nix_expr=$(debug_eval_daily_nix_expr)
  nix_expr=${nix_expr//REPO_ROOT/$REPO_ROOT}
  nix_expr=${nix_expr//ATTR_PATH/$attr}
  nix_expr=${nix_expr//EXTRA_MODULE/$extraModule}
  nix --extra-experimental-features 'nix-command flakes' eval --impure --json --no-write-lock-file --expr "$nix_expr" 2>/dev/null
}

describe 'debug.crossProfileLogin.enable: lifts the account locks'
cross='{ myOS.debug = { enable = true; crossProfileLogin.enable = true; warnings.enable = false; }; }'
daily_pwf_cross=$(_debug_eval 'users.users.test_daily.hashedPasswordFile' "$cross")
assert_eq "$daily_pwf_cross" '"/persist/secrets/test_daily-password.hash"' \
  'paranoid + crossProfileLogin: test_daily.hashedPasswordFile is set (cross-profile)'
daily_pw_cross=$(_debug_eval 'users.users.test_daily.hashedPassword' "$cross")
assert_eq "$daily_pw_cross" 'null' \
  'paranoid + crossProfileLogin: test_daily.hashedPassword is null (lock lifted)'
paranoid_pwf_cross=$(_debug_eval 'users.users.test_paranoid.hashedPasswordFile' "$cross")
assert_eq "$paranoid_pwf_cross" '"/persist/secrets/test_paranoid-password.hash"' \
  'paranoid + crossProfileLogin: test_paranoid.hashedPasswordFile still set'
paranoid_pwf_cross_d=$(_debug_eval_daily 'users.users.test_paranoid.hashedPasswordFile' "$cross")
assert_eq "$paranoid_pwf_cross_d" '"/persist/secrets/test_paranoid-password.hash"' \
  'daily + crossProfileLogin: test_paranoid.hashedPasswordFile is set (cross-profile)'
paranoid_pw_cross_d=$(_debug_eval_daily 'users.users.test_paranoid.hashedPassword' "$cross")
assert_eq "$paranoid_pw_cross_d" 'null' \
  'daily + crossProfileLogin: test_paranoid.hashedPassword is null (lock lifted)'

describe "debug.paranoidWheel.enable: adds wheel + relaxes governance"
wheel_mod='{ myOS.debug = { enable = true; paranoidWheel.enable = true; warnings.enable = false; }; }'
paranoid_groups_wheel=$(_debug_eval 'users.users.test_paranoid.extraGroups' "$wheel_mod")
if jq_cmd -e '. | index("wheel")' <<<"$paranoid_groups_wheel" >/dev/null 2>&1; then
  pass "paranoid + paranoidWheel: test_paranoid has 'wheel' in extraGroups"
else
  fail "paranoid + paranoidWheel: test_paranoid missing 'wheel' in extraGroups" "$paranoid_groups_wheel"
fi

# With paranoidWheel on, the governance assertion should not fire.
# We verify this indirectly by checking that the eval succeeds and produces
# a drv path for the system.
drv_with_wheel=$(_debug_eval 'system.build.toplevel.drvPath' "$wheel_mod" || true)
if [[ -n "$drv_with_wheel" && "$drv_with_wheel" != 'null' ]]; then
  pass 'paranoid + paranoidWheel: toplevel drv evaluates (governance assertion relaxed)'
else
  fail 'paranoid + paranoidWheel: eval failed; governance may be over-strict'
fi

describe "sub-flag without master gate is a no-op"
# crossProfileLogin=true but enable=false: behaviour must match the default.
sub_only='{ myOS.debug = { enable = false; crossProfileLogin.enable = true; }; }'
daily_pwf_noop=$(_debug_eval 'users.users.test_daily.hashedPasswordFile' "$sub_only")
assert_eq "$daily_pwf_noop" 'null' \
  'sub-flag without master gate: test_daily.hashedPasswordFile still null on paranoid'
daily_pw_noop=$(_debug_eval 'users.users.test_daily.hashedPassword' "$sub_only")
assert_eq "$daily_pw_noop" '"!"' \
  'sub-flag without master gate: test_daily.hashedPassword still "!" on paranoid'

# paranoidWheel=true but enable=false: test_paranoid must still not be in wheel.
wheel_noop='{ myOS.debug = { enable = false; paranoidWheel.enable = true; }; }'
paranoid_groups_noop=$(_debug_eval 'users.users.test_paranoid.extraGroups' "$wheel_noop")
if jq_cmd -e '. | index("wheel")' <<<"$paranoid_groups_noop" >/dev/null 2>&1; then
  fail 'sub-flag without master gate: test_paranoid has wheel' "$paranoid_groups_noop"
else
  pass 'sub-flag without master gate: test_paranoid still not in wheel'
fi

describe "warnings.enable: activation warning surface when relaxations are on"
warn_mod='{ myOS.debug = { enable = true; crossProfileLogin.enable = true; paranoidWheel.enable = true; warnings.enable = true; }; }'
warnings=$(_debug_eval 'warnings' "$warn_mod" || echo null)
if jq_cmd -e 'type == "array" and (.[] | test("crossProfileLogin")) and (.[] | test("paranoidWheel"))' <<<"$warnings" >/dev/null 2>&1; then
  pass 'warnings list contains both crossProfileLogin and paranoidWheel notices'
else
  # Less strict: at least one warning mentions a debug relaxation.
  if jq_cmd -e 'type == "array" and (any(.[]; test("myOS.debug")))' <<<"$warnings" >/dev/null 2>&1; then
    pass 'warnings list contains a myOS.debug notice (both flags on)'
  else
    fail 'warnings list does not mention myOS.debug relaxations' "$warnings"
  fi
fi
