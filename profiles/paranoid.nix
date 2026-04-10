{ config, lib, pkgs, ... }:
{
  # mkForce required: specialisations merge with the base config via
  # extendModules. Without mkForce, options that differ from daily.nix
  # trigger "conflicting definition values" (mergeEqualOption).
  myOS.profile = lib.mkForce "paranoid";
  myOS.security = {
    mullvad.lockdown = lib.mkForce true;
    browserLockdown.enable = lib.mkForce true;
    disableSMT = lib.mkForce true;
    gamingSysctls = lib.mkForce false;
    usbRestrict = lib.mkForce true;
    auditd = lib.mkForce true;
    kernelHardening = {
      initOnFree = lib.mkForce true;
      pageAllocShuffle = lib.mkForce true;
    };
  };

  programs.steam.enable = lib.mkForce false;
  programs.gamescope.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;
  services.wivrn.enable = lib.mkForce false;

  # Keep KDE + NVIDIA at first for reliability on this hardware.
}
