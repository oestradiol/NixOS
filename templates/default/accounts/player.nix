# Reference account: player — the daily-desktop persona.
#
# Pure data: declares the user's identity shape via the two-axis
# framework (modules/core/users-framework.nix). The system side is
# wired by modules/core/users.nix reading this attrset.
#
# `allowWheel = true` adds the wheel group automatically; do not list
# it in `extraGroups` directly.
{ pkgs, lib, ... }:
let
  localFile = ./player.local.nix;
in {
  imports = lib.optional (builtins.pathExists localFile) localFile;

  myOS.users.player = {
    activeOnProfiles = [ "daily" ];
    description = "Daily desktop";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
      "realtime"
      "gamemode"
    ];
    allowWheel = true;
    home = {
      persistent = true;
      btrfsSubvol = "@home-daily";
    };
    homeManagerConfig = ./home/player.nix;
  };
}
