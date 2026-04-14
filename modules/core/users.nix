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
      "libvirtd"
      "kvm"
    ];
    # No initial password - must be set before first boot via initialPassword, hashedPassword, or chroot
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
    # No initial password - must be set before first boot via initialPassword, hashedPassword, or chroot
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
