{ config, lib, pkgs, inputs, ... }:
let
  system = "x86_64-linux";
in {
  imports = [
    ./hardware-target.nix
    ../../accounts/ghost.nix
    ../../accounts/player.nix
    inputs.hardening.nixosModules.profile-paranoid
  ];

  # networking.hostName / time.timeZone are now applied by
  # modules/core/host.nix via myOS.host.* options.
  system.stateVersion = "26.05";

  environment.systemPackages = with pkgs; [
    comma
    curl
    git
    vim
    wget
    pciutils
    usbutils
    cryptsetup
    sbctl
    tpm2-tools
    age
    inputs.agenix.packages.${system}.default
    bubblewrap
    flatpak
  ];

  specialisation = {
    daily.configuration = {
      imports = [ inputs.hardening.nixosModules.profile-daily ];
    };
  };
}
