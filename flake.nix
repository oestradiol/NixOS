{
  description = "NixOS: hardened workstation baseline with explicit daily relaxation specialisation";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, stylix, impermanence, lanzaboote, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    # ── nixosModules: per-feature library outputs (Stage 6) ─────────────
    # Consumers with an existing flake import only what they need:
    #
    #   inputs.hardening.url = "github:oestradiol/NixOS";
    #   outputs = { nixpkgs, hardening, ... }: {
    #     nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
    #       modules = [
    #         hardening.nixosModules.core
    #         hardening.nixosModules.users-framework
    #         hardening.nixosModules.security-kernel-hardening
    #         # ...
    #         { myOS.profile = "paranoid";
    #           myOS.users.alice = { activeOnProfiles = [ "paranoid" ]; ... };
    #         }
    #       ];
    #     };
    #   };
    #
    # `default` aggregates the full stack. Every other output is a single
    # file so integrators can cherry-pick at capability granularity.
    nixosModules = {
      default = { imports = [
        ./modules/core/options.nix
        ./modules/core/storage-layout.nix
        ./modules/core/boot.nix
        ./modules/core/debug.nix
        ./modules/core/host.nix
        ./modules/core/users.nix
        ./modules/core/users-framework.nix
        ./modules/desktop/base.nix
        ./modules/gpu/nvidia.nix
        ./modules/gpu/amd.nix
        ./modules/security/base.nix
      ]; };

      # Core
      core = { imports = [
        ./modules/core/options.nix
        ./modules/core/storage-layout.nix
        ./modules/core/boot.nix
        ./modules/core/debug.nix
        ./modules/core/host.nix
        ./modules/core/users.nix
        ./modules/core/users-framework.nix
      ]; };
      core-options                  = ./modules/core/options.nix;
      core-storage-layout           = ./modules/core/storage-layout.nix;
      core-boot                     = ./modules/core/boot.nix;
      core-debug                    = ./modules/core/debug.nix;
      core-host                     = ./modules/core/host.nix;
      core-users                    = ./modules/core/users.nix;
      users-framework               = ./modules/core/users-framework.nix;

      # Desktop
      desktop                       = ./modules/desktop/base.nix;
      desktop-auto-update           = ./modules/desktop/auto-update.nix;
      desktop-controllers           = ./modules/desktop/controllers.nix;
      desktop-gaming                = ./modules/desktop/gaming.nix;
      desktop-greeter               = ./modules/desktop/greeter.nix;
      desktop-hyprland              = ./modules/desktop/hyprland.nix;
      desktop-i18n                  = ./modules/desktop/i18n.nix;
      desktop-plasma                = ./modules/desktop/plasma.nix;
      desktop-theme                 = ./modules/desktop/theme.nix;
      desktop-vr                    = ./modules/desktop/vr.nix;

      # GPU
      gpu-nvidia                    = ./modules/gpu/nvidia.nix;
      gpu-amd                       = ./modules/gpu/amd.nix;

      # Home
      desktop-shell                 = ./modules/home/shell.nix;
      home-shell                    = ./modules/home/shell.nix;
      home-common                   = ./modules/home/common.nix;

      # Security
      security                      = ./modules/security/base.nix;
      security-browser              = ./modules/security/browser.nix;
      security-flatpak              = ./modules/security/flatpak.nix;
      security-governance           = ./modules/security/governance.nix;
      security-impermanence         = ./modules/security/impermanence.nix;
      security-kernel-hardening     = ./modules/security/kernel-hardening.nix;
      security-networking           = ./modules/security/networking.nix;
      security-privacy              = ./modules/security/privacy.nix;
      security-sandbox              = ./modules/security/sandbox.nix;
      security-sandbox-core         = ./modules/security/sandbox-core.nix;
      security-sandboxed-apps       = ./modules/security/sandboxed-apps.nix;
      security-scanners             = ./modules/security/scanners.nix;
      security-secrets              = ./modules/security/secrets.nix;
      security-secure-boot          = ./modules/security/secure-boot.nix;
      security-user-profile-binding = ./modules/security/user-profile-binding.nix;
      security-vm-tooling           = ./modules/security/vm-tooling.nix;
      security-wireguard            = ./modules/security/wireguard.nix;

      # Reference profiles (system postures).
      profile-paranoid              = ./profiles/paranoid.nix;
      profile-daily                 = ./profiles/daily.nix;
    };

    templates = {
      workstation = {
        path = "${self}/templates/workstation";
        description = "Hardened workstation bootstrap using the oestradiol/NixOS framework";
      };
    };

    checks.${system} = {
      required-files = pkgs.runCommand "required-files-check" {} ''
        echo "Checking required files..."
        for f in ${./.}/docs/governance/PROJECT-STATE.md ${./.}/flake.nix ${./.}/docs/maps/SECURITY-SURFACES.md; do
          test -f "$f" || { echo "Missing: $f" > $out; exit 1; }
        done
        echo "All required files present" > $out
      '';
    };
  };
}
