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
    vmIsolation.enable = true;
  };

  imports = [ ../modules/desktop/gaming.nix ];
}
