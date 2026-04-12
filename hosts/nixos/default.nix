{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-target.nix
    ./install-layout.nix
    # Core
    ../../modules/core/options.nix
    ../../modules/core/base-desktop.nix
    ../../modules/core/boot.nix
    ../../modules/core/users.nix
    # Security
    ../../modules/security/base.nix
    ../../modules/security/governance.nix
    ../../modules/security/networking.nix
    ../../modules/security/browser.nix
    ../../modules/security/impermanence.nix
    ../../modules/security/secrets.nix
    ../../modules/security/secure-boot.nix
    ../../modules/security/flatpak.nix
    ../../modules/security/scanners.nix
    ../../modules/security/vm-isolation.nix  # Disabled by default, knob: myOS.security.vmIsolation.enable
    ../../modules/security/sandboxed-apps.nix
    ../../modules/security/privacy.nix
    ../../modules/security/user-profile-binding.nix
    # Desktop
    ../../modules/gpu/nvidia.nix
    ../../modules/gpu/amd.nix
    ../../modules/desktop/theme.nix
    # Profile
    ../../profiles/daily.nix
  ];

  networking.hostName = "nixos";
  time.timeZone = "America/Sao_Paulo";
  system.stateVersion = "26.05";

  # System-wide staged controls — these affect the bootloader and initrd,
  # which are shared across all specialisations. Flip to true only after
  # the first successful encrypted boot. See docs/POST-STABILITY.md.
  myOS.security.secureBoot.enable = false;
  myOS.security.tpm.enable = false;

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
    agenix
    bubblewrap
    flatpak
    mullvad-vpn
  ];

  specialisation = {
    paranoid.configuration = {
      imports = [ ../../profiles/paranoid.nix ];
    };
  };
}
