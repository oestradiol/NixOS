# Test fixture: minimal host importing framework modules
# Used by eval-cache.nix and tests to verify the framework works
{ config, lib, pkgs, inputs, ... }:
let
  hardening = inputs.self.nixosModules;
in {
  imports = [
    # Minimal host configuration for testing
    {
      # Mock fs-layout for testing (no actual disk dependencies)
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
      
      # Test users
      myOS.users.player = {
        activeOnProfiles = [ "daily" ];
        description = "Daily desktop";
        shell = pkgs.zsh;
        extraGroups = [ "networkmanager" "video" "audio" ];
        allowWheel = true;
        home.persistent = true;
      };
      
      myOS.users.ghost = {
        activeOnProfiles = [ "paranoid" ];
        description = "Hardened workspace";
        uid = 1001;
        shell = pkgs.zsh;
        extraGroups = [ "networkmanager" "video" "audio" ];
        allowWheel = false;
        home.persistent = false;
      };
    }
    hardening.core
    hardening.users-framework
    hardening.profile-paranoid
  ];
  
  specialisation = {
    daily.configuration = {
      imports = [ hardening.profile-daily ];
    };
  };
  
  system.stateVersion = "26.05";
}
