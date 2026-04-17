{ pkgs, config, lib, ... }:
let
  lockRoot = config.myOS.security.lockRoot;
  isDaily = config.myOS.profile == "daily";
  isParanoid = config.myOS.profile == "paranoid";

  # Debug-mode relaxations — off unless the master gate is also on.
  debug = config.myOS.debug;
  crossProfile = debug.enable && debug.crossProfileLogin.enable;
  paranoidWheel = debug.enable && debug.paranoidWheel.enable;
in {
  # NOTE: mutableUsers=false means /etc/{passwd,group,shadow,gshadow,subuid,subgid}
  # are regenerated from NixOS config on every activation — no persistence needed.
  # Passwords are read declaratively from hashedPasswordFile on the persist volume.
  #
  # FIRST BOOT PASSWORD SETUP:
  # The install script (scripts/rebuild-install.sh) writes hashed passwords to
  # /persist/secrets/{player,ghost}-password.hash before nixos-install.
  users.mutableUsers = false;

  users.users.player = {
    isNormalUser = true;
    description = "Daily desktop";
    home = "/home/player";
    shell = pkgs.zsh;
    group = "users";  # Use standard users group (GID typically 100)
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "realtime"
      "gamemode"
    ];
    # Profile binding: player authenticates on daily, locked on paranoid.
    # myOS.debug.crossProfileLogin.enable lifts the paranoid-side lock and
    # sets hashedPasswordFile on both profiles (see modules/core/debug.nix).
    hashedPasswordFile = lib.mkIf (isDaily || crossProfile) "/persist/secrets/player-password.hash";
    hashedPassword = lib.mkIf (isParanoid && !crossProfile) "!";
  };

  # On paranoid, player is locked and ghost (the actual auth target) is not
  # in the wheel group — which means no wheel user has a password, and NixOS
  # would otherwise refuse to activate with "you will be locked out".
  # `allowNoPasswordLogin = true` acknowledges that the auth target is the
  # non-wheel ghost account on paranoid. Daily has player in wheel with a
  # password, so the normal NixOS invariant is already satisfied.
  users.allowNoPasswordLogin = isParanoid;

  users.users."ghost" = {
    isNormalUser = true;
    uid = 1001;  # Explicit for hardware-target.nix tmpfs mount
    description = "Hardened workspace";
    home = "/home/ghost";
    shell = pkgs.zsh;
    group = "users";
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
    ] ++ lib.optional paranoidWheel "wheel";
    # Profile binding: ghost authenticates on paranoid, locked on daily.
    # myOS.debug.crossProfileLogin.enable lifts the daily-side lock and
    # sets hashedPasswordFile on both profiles (see modules/core/debug.nix).
    hashedPasswordFile = lib.mkIf (isParanoid || crossProfile) "/persist/secrets/ghost-password.hash";
    hashedPassword = lib.mkIf (isDaily && !crossProfile) "!";
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
