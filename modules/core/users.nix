{ pkgs, config, lib, ... }:
{
  users.mutableUsers = false;

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
    initialHashedPassword = lib.mkDefault "!";
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
    initialHashedPassword = lib.mkDefault "!";
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };
}
