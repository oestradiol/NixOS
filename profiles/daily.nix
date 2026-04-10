{ config, lib, pkgs, ... }:
{
  myOS.profile = "daily";
  myOS.gpu = "nvidia";
  myOS.security = {
    impermanence.enable = true;
    agenix.enable = true;
    mullvad.enable = true;
    mullvad.lockdown = false;
    hardenedMemory.enable = false;
    browserLockdown.enable = false;
    disableSMT = false;
  };

  imports = [ ../modules/desktop/gaming.nix ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
}
