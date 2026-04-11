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
    ptraceScope = 1;  # Required for VRChat EAC
    swappiness = 20;  # Better for gaming with 16GB RAM (safety margin)
    sandboxedApps.enable = true;
  };

  imports = [ ../modules/desktop/gaming.nix ];
}
