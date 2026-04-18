{ config, lib, pkgs, inputs, ... }:
let
  system = "x86_64-linux";
  # Conditionally pull in operator-local overrides (per-install hardware
  # quirks, experimental toggles). The file is gitignored; when it is
  # missing, the import list simply drops the entry. See hosts/nixos/local.nix
  # (if present) and README.md for the policy.
  localOverride = ./local.nix;
in {
  imports = [
    ./fs-layout.nix
    ./hardware-target.nix
    ../../modules/core/options.nix
    ../../modules/core/host.nix
    ../../modules/core/debug.nix
    ../../modules/core/users-framework.nix
    ../../modules/core/boot.nix
    ../../modules/core/users.nix
    ../../modules/desktop/base.nix
    ../../modules/gpu/nvidia.nix
    ../../modules/gpu/amd.nix
    ../../modules/security/base.nix
    ../../profiles/paranoid.nix
  ] ++ lib.optional (builtins.pathExists localOverride) localOverride;

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
      imports = [ ../../profiles/daily.nix ];
    };
  };
}
