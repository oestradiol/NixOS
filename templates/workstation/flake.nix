# Minimal workstation bootstrap using the oestradiol/NixOS framework.
#
# Usage (as a fresh flake):
#
#   nix flake init -t github:oestradiol/NixOS#workstation
#   $EDITOR flake.nix        # set hostName, GPU, user identity
#   sudo nixos-rebuild switch --flake .#workstation
#
# This template assembles a single hardened workstation with one
# permissive daily user on the `daily` profile. For the full paranoid
# + daily specialisation split, copy the reference host at
# `templates/default/` in the upstream repo instead.
{
  description = "Hardened NixOS workstation (oestradiol/NixOS framework template)";

  inputs = {
    nixpkgs.url                   = "github:nixos/nixpkgs/nixos-unstable";
    hardening.url                 = "github:oestradiol/NixOS";
    hardening.inputs.nixpkgs.follows = "nixpkgs";
    agenix.follows                = "hardening/agenix";
    lanzaboote.follows            = "hardening/lanzaboote";
    stylix.follows                = "hardening/stylix";

    home-manager.url                  = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url                  = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, hardening, agenix, lanzaboote, stylix, home-manager, impermanence, ... }:
    let
      hardwareTarget = ./hardware-target.nix;
      identityLocal = ./identity.local.nix;
      localOverride = ./local.nix;
    in {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.config.allowUnfree = true; }

        # ── Framework substrate ──────────────────────────────────────
        # Pick the capabilities you actually want. `core` is the
        # framework-owned baseline, including the default storage model.
        hardening.nixosModules.core
        hardening.nixosModules.profile-daily

        hardening.nixosModules.security                  # base.nix: assembles the security stack
        hardening.nixosModules.security-governance
        hardening.nixosModules.security-kernel-hardening
        hardening.nixosModules.security-browser          # safe-firefox wrapper
        hardening.nixosModules.security-flatpak
        hardening.nixosModules.security-impermanence
        hardening.nixosModules.security-scanners
        hardening.nixosModules.security-networking

        hardening.nixosModules.desktop                   # base.nix: Plasma 6 + greetd
        hardening.nixosModules.desktop-plasma
        hardening.nixosModules.desktop-theme
        hardening.nixosModules.desktop-auto-update

        hardening.nixosModules.gpu-nvidia                # swap for gpu-amd as needed

        # ── Flake inputs that the framework modules expect ───────────
        agenix.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence

        # ── Host-specific choices ────────────────────────────────────
        {
          # Wire home-manager in global-pkgs mode.
          home-manager = {
            useGlobalPkgs     = true;
            useUserPackages   = true;
            backupFileExtension = "bkp";
            extraSpecialArgs = { inherit inputs; };
          };

          # System posture (only `daily` is active in this template).
          myOS.profile = "daily";
          myOS.gpu     = "nvidia";
          myOS.autoUpdate.enable = false;
          myOS.host.hostName = "workstation";
          myOS.host.timeZone = "Etc/UTC";

          # Declare a single permissive user on the daily posture.
          # Replace the identity values with your own, ideally in a
          # gitignored `./identity.local.nix` that this flake imports.
          myOS.users.alice = {
            activeOnProfiles = [ "daily" ];
            description      = "Primary user";
            allowWheel       = true;
            extraGroups      = [ "networkmanager" "video" "audio" "input" ];
            home.persistent  = true;
            homeManagerConfig = ./home/alice.nix;
            identity.git.name  = "Ada Lovelace";
            identity.git.email = "ada@example.com";
          };

          # Tracked file carries no identity. Put real values in the
          # gitignored ./identity.local.nix override instead.
          # imports = [ ./identity.local.nix ];

          system.stateVersion = "26.05";
        }
      ]
      ++ nixpkgs.lib.optional (builtins.pathExists hardwareTarget) hardwareTarget
      ++ nixpkgs.lib.optional (builtins.pathExists identityLocal) identityLocal
      ++ nixpkgs.lib.optional (builtins.pathExists localOverride) localOverride;
    };
  };
}
