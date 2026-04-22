# Test fixture: minimal host importing framework modules
# Used by eval-cache.nix and tests to verify the framework works
{ config, lib, pkgs, inputs, ... }:
let
  hardening = inputs.self.nixosModules;
in {
  imports = [
    # Minimal host configuration for testing
    {
      # Use the framework-owned storage defaults; eval does not require the
      # referenced devices to exist on disk.
      boot.loader.grub.enable = false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
      
      # Test users (template-agnostic: verify framework behavior without
      # hardcoding template-specific user names like player/ghost)
      myOS.users.test_daily = {
        activeOnProfiles = [ "daily" ];
        description = "Test daily user";
        shell = pkgs.zsh;
        extraGroups = [ "networkmanager" "video" "audio" ];
        allowWheel = true;
        home.persistent = true;
      };

      myOS.users.test_paranoid = {
        activeOnProfiles = [ "paranoid" ];
        description = "Test paranoid user";
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
