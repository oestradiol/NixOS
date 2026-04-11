{ pkgs, config, lib, ... }:
let
  lockRoot = config.myOS.security.lockRoot;
in {
  users.mutableUsers = !lockRoot;

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
    initialHashedPassword = lib.mkIf lockRoot (lib.mkDefault "!");
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
    initialHashedPassword = lib.mkIf lockRoot (lib.mkDefault "!");
  };

  security.sudo = lib.mkIf lockRoot {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
