{ config, lib, pkgs, inputs, ... }:
let
  system = "x86_64-linux";
in {
  imports = [
    ./fs-layout.nix
    ./hardware-target.nix
    ../../modules/core/options.nix
    ../../modules/core/boot.nix
    ../../modules/core/users.nix
    ../../modules/desktop/base.nix
    ../../modules/gpu/nvidia.nix
    ../../modules/gpu/amd.nix
    ../../modules/security/base.nix
    ../../profiles/paranoid.nix
  ];

  networking.hostName = "nixos";
  time.timeZone = "America/Sao_Paulo";
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
      imports = [ ../../profiles/daily.nix ];
    };
  };
}
