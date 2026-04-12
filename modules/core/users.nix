{ pkgs, config, lib, ... }:
let
  lockRoot = config.myOS.security.lockRoot;
in {
  # NOTE: mutableUsers=true with tmpfs root requires /etc/{passwd,group,shadow,
  # gshadow,subuid,subgid} to be persisted. These are now in impermanence.nix.
  #
  # FIRST BOOT PASSWORD SETUP (before first boot):
  # You must set an initial password via configuration before first boot:
  #   users.users.player.initialPassword = "temp123";
  # Or use a hashed password:
  #   users.users.player.hashedPassword = "...";
  # Or set interactively during install:
  #   sudo nixos-install --flake ... && sudo passwd player (in chroot)
  #
  # CRITICAL: NixOS users WITHOUT a password CANNOT log in via password-based
  # mechanisms (including TTY). See: https://nixos.org/manual/nixos/stable/options#opt-users.mutableUsers
  users.mutableUsers = true;

  users.users.player = {
    isNormalUser = true;
    description = "Daily desktop";
    home = "/home/player";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "realtime"
      "gamemode"
      "libvirtd"
      "kvm"
      "flatpak"
    ];
    # No initial password - user must set via TTY on first boot (see above)
  };

  users.users."ghost" = {
    isNormalUser = true;
    description = "Hardened workspace";
    home = "/home/ghost";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "flatpak"
    ];
    # No initial password - user must set via TTY on first boot (see above)
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
