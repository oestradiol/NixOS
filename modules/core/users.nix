# Stage 4b: framework-driven user wiring.
#
# Reads every `myOS.users.<name>` entry declared by the accounts files
# (`accounts/*.nix`) and materialises:
#
#   1. `users.users.<name>`        — Unix account with profile locking
#   2. `home-manager.users.<name>` — HM config for users active on
#                                    the current profile only
#   3. `users.allowNoPasswordLogin` — NixOS invariant escape hatch
#   4. `security.sudo`              — root-lock posture (unchanged)
#
# Profile locking rules:
#   active user (`_activeOn = true`)  → hashedPasswordFile set
#   inactive user                     → hashedPassword = "!"
#   debug.crossProfileLogin lifts both lock types on all users.
#
# Wheel membership rules:
#   allowWheel = true                 → wheel always added
#   debug.paranoidWheel.enable        → wheel added to every user
#                                       regardless of allowWheel
#                                       (matches legacy behaviour)
#
# `users.allowNoPasswordLogin` is true when no active user carries
# wheel — a necessary acknowledgement because NixOS refuses to
# activate a system where every wheel user lacks a password.
{ pkgs, config, lib, ... }:
let
  cfg = config.myOS;
  lockRoot = cfg.security.lockRoot;
  debug = cfg.debug;
  crossProfile = debug.enable && debug.crossProfileLogin.enable;
  paranoidWheel = debug.enable && debug.paranoidWheel.enable;

  enabledUsers = lib.filterAttrs (_: u: u.enable) cfg.users;

  effectivelyInWheel = u: u.allowWheel || paranoidWheel;

  buildUser = name: u: ({
    isNormalUser = true;
    description = u.description;
    home = "/home/${name}";
    shell = u.shell;
    group = "users";  # Standard group (GID 100).
    extraGroups = u.extraGroups ++ lib.optional (effectivelyInWheel u) "wheel";
    # Profile binding: active user gets hashedPasswordFile; inactive
    # user gets a locked "!" sentinel. debug.crossProfileLogin flips
    # both profiles on (hashedPasswordFile everywhere) for dev.
    hashedPasswordFile = lib.mkIf (u._activeOn || crossProfile)
      "/persist/secrets/${name}-password.hash";
    hashedPassword = lib.mkIf (!u._activeOn && !crossProfile) "!";
  } // lib.optionalAttrs (u.uid != null) { inherit (u) uid; });

  hmActive = lib.filterAttrs (_: u: u._activeOn && u.homeManagerConfig != null) enabledUsers;

  # If any active user is effectively in wheel we have a wheel user
  # with a password, and allowNoPasswordLogin is not needed.
  anyActiveWheel =
    lib.any (u: u._activeOn && effectivelyInWheel u)
            (builtins.attrValues enabledUsers);
in {
  users.mutableUsers = false;

  users.users = lib.mapAttrs buildUser enabledUsers;

  # Required when the active persona is non-wheel (e.g. paranoid/ghost):
  # no wheel user then has a password, and NixOS refuses activation
  # otherwise.
  users.allowNoPasswordLogin = !anyActiveWheel;

  # home-manager binds only for active users. Inactive personas get
  # their HM profile skipped to keep the build lean and avoid building
  # a profile that can never be used.
  home-manager.users =
    lib.mapAttrs (_: u: { imports = [ u.homeManagerConfig ]; }) hmActive;

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
