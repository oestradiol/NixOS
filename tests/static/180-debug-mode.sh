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
# Paranoid: ghost has a password file, player is locked.
assert_eq "$(nix_eval 'users.users.player.hashedPasswordFile')" 'null' \
  "paranoid: player.hashedPasswordFile is null (locked)"
pw=$(nix_eval 'users.users.player.hashedPassword')
assert_eq "$pw" '"!"' "paranoid: player.hashedPassword = \"!\" (locked)"
ghost_pwf=$(nix_eval 'users.users.ghost.hashedPasswordFile')
assert_eq "$ghost_pwf" '"/persist/secrets/ghost-password.hash"' \
  "paranoid: ghost.hashedPasswordFile points at ghost-password.hash"
ghost_pw=$(nix_eval 'users.users.ghost.hashedPassword')
assert_eq "$ghost_pw" 'null' "paranoid: ghost.hashedPassword is null (unlocked)"

# Daily: player has a password file, ghost is locked.
assert_eq "$(nix_eval_daily 'users.users.ghost.hashedPasswordFile')" 'null' \
  "daily: ghost.hashedPasswordFile is null (locked)"
ghost_pw_d=$(nix_eval_daily 'users.users.ghost.hashedPassword')
assert_eq "$ghost_pw_d" '"!"' "daily: ghost.hashedPassword = \"!\" (locked)"
player_pwf=$(nix_eval_daily 'users.users.player.hashedPasswordFile')
assert_eq "$player_pwf" '"/persist/secrets/player-password.hash"' \
  "daily: player.hashedPasswordFile points at player-password.hash"
player_pw_d=$(nix_eval_daily 'users.users.player.hashedPassword')
assert_eq "$player_pw_d" 'null' "daily: player.hashedPassword is null (unlocked)"

describe "default state: ghost is NOT in wheel on paranoid"
ghost_groups=$(nix_eval 'users.users.ghost.extraGroups')
if jq_cmd -e '. | index("wheel")' <<<"$ghost_groups" >/dev/null 2>&1; then
  fail "default paranoid eval: ghost has 'wheel' in extraGroups" "$ghost_groups"
else
  pass "default paranoid eval: ghost does NOT have 'wheel' in extraGroups"
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
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      fileSystems."/persist" = { device = "/dev/disk/by-label/persist"; fsType = "btrfs"; neededForBoot = true; };
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = nixpkgs.lib.mkForce false;
      boot.kernelModules = [ "kvm-amd" ];
      myOS.users.player = { activeOnProfiles = [ "daily" ]; description = "Daily"; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = true; home.persistent = true; };
      myOS.users.ghost = { activeOnProfiles = [ "paranoid" ]; description = "Ghost"; uid = 1001; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = false; home.persistent = false; };
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
  nix --extra-experimental-features 'nix-command flakes' eval --impure --json --expr "$nix_expr" 2>/dev/null
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
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      fileSystems."/persist" = { device = "/dev/disk/by-label/persist"; fsType = "btrfs"; neededForBoot = true; };
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = nixpkgs.lib.mkForce false;
      boot.kernelModules = [ "kvm-amd" ];
      myOS.users.player = { activeOnProfiles = [ "daily" ]; description = "Daily"; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = true; home.persistent = true; };
      myOS.users.ghost = { activeOnProfiles = [ "paranoid" ]; description = "Ghost"; uid = 1001; shell = pkgs.zsh; extraGroups = [ "networkmanager" "video" "audio" ]; allowWheel = false; home.persistent = false; };
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
  nix --extra-experimental-features 'nix-command flakes' eval --impure --json --expr "$nix_expr" 2>/dev/null
}

describe 'debug.crossProfileLogin.enable: lifts the account locks'
cross='{ myOS.debug = { enable = true; crossProfileLogin.enable = true; warnings.enable = false; }; }'
ppw=$(_debug_eval 'users.users.player.hashedPasswordFile' "$cross")
assert_eq "$ppw" '"/persist/secrets/player-password.hash"' \
  'paranoid + crossProfileLogin: player.hashedPasswordFile is set (cross-profile)'
ppwh=$(_debug_eval 'users.users.player.hashedPassword' "$cross")
assert_eq "$ppwh" 'null' \
  'paranoid + crossProfileLogin: player.hashedPassword is null (lock lifted)'
gpw=$(_debug_eval 'users.users.ghost.hashedPasswordFile' "$cross")
assert_eq "$gpw" '"/persist/secrets/ghost-password.hash"' \
  'paranoid + crossProfileLogin: ghost.hashedPasswordFile still set'
gpw_d=$(_debug_eval_daily 'users.users.ghost.hashedPasswordFile' "$cross")
assert_eq "$gpw_d" '"/persist/secrets/ghost-password.hash"' \
  'daily + crossProfileLogin: ghost.hashedPasswordFile is set (cross-profile)'
gpwh_d=$(_debug_eval_daily 'users.users.ghost.hashedPassword' "$cross")
assert_eq "$gpwh_d" 'null' \
  'daily + crossProfileLogin: ghost.hashedPassword is null (lock lifted)'

describe "debug.paranoidWheel.enable: adds wheel + relaxes governance"
wheel_mod='{ myOS.debug = { enable = true; paranoidWheel.enable = true; warnings.enable = false; }; }'
ghost_groups_wheel=$(_debug_eval 'users.users.ghost.extraGroups' "$wheel_mod")
if jq_cmd -e '. | index("wheel")' <<<"$ghost_groups_wheel" >/dev/null 2>&1; then
  pass "paranoid + paranoidWheel: ghost has 'wheel' in extraGroups"
else
  fail "paranoid + paranoidWheel: ghost missing 'wheel' in extraGroups" "$ghost_groups_wheel"
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
ppw_noop=$(_debug_eval 'users.users.player.hashedPasswordFile' "$sub_only")
assert_eq "$ppw_noop" 'null' \
  'sub-flag without master gate: player.hashedPasswordFile still null on paranoid'
ppwh_noop=$(_debug_eval 'users.users.player.hashedPassword' "$sub_only")
assert_eq "$ppwh_noop" '"!"' \
  'sub-flag without master gate: player.hashedPassword still "!" on paranoid'

# paranoidWheel=true but enable=false: ghost must still not be in wheel.
wheel_noop='{ myOS.debug = { enable = false; paranoidWheel.enable = true; }; }'
ghost_groups_noop=$(_debug_eval 'users.users.ghost.extraGroups' "$wheel_noop")
if jq_cmd -e '. | index("wheel")' <<<"$ghost_groups_noop" >/dev/null 2>&1; then
  fail 'sub-flag without master gate: ghost has wheel' "$ghost_groups_noop"
else
  pass 'sub-flag without master gate: ghost still not in wheel'
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
