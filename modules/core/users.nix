{ pkgs, config, lib, ... }:
let
  lockRoot = config.myOS.security.lockRoot;
  isDaily = config.myOS.profile == "daily";
  isParanoid = config.myOS.profile == "paranoid";
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
    # Same mechanism as root locking in base.nix.  Recovery: boot the other profile.
    hashedPasswordFile = lib.mkIf isDaily "/persist/secrets/player-password.hash";
    hashedPassword = lib.mkIf isParanoid "!";
  };

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
    ];
    # Profile binding: ghost authenticates on paranoid, locked on daily.
    hashedPasswordFile = lib.mkIf isParanoid "/persist/secrets/ghost-password.hash";
    hashedPassword = lib.mkIf isDaily "!";
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
