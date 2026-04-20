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
# `hosts/nixos/` in the upstream repo instead.
{
  description = "Hardened NixOS workstation (oestradiol/NixOS framework template)";

  inputs = {
    nixpkgs.url                   = "github:nixos/nixpkgs/nixos-unstable";
    hardening.url                 = "github:oestradiol/NixOS";
    hardening.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url                  = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url                  = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, hardening, home-manager, impermanence, ... }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # ── Framework substrate ──────────────────────────────────────
        # Pick the capabilities you actually want. `core` +
        # `users-framework` are the minimum; the rest are opt-in.
        hardening.nixosModules.core
        hardening.nixosModules.core-boot
        hardening.nixosModules.core-host
        hardening.nixosModules.core-debug
        hardening.nixosModules.users-framework
        hardening.nixosModules.core-users

        hardening.nixosModules.security                  # base.nix: assembles the security stack
        hardening.nixosModules.security-governance
        hardening.nixosModules.security-kernel-hardening
        hardening.nixosModules.security-sandbox-core
        hardening.nixosModules.security-browser          # safe-firefox wrapper
        hardening.nixosModules.security-flatpak
        hardening.nixosModules.security-impermanence
        hardening.nixosModules.security-scanners
        hardening.nixosModules.security-networking

        hardening.nixosModules.desktop                   # base.nix: Plasma 6 + greetd
        hardening.nixosModules.desktop-plasma
        hardening.nixosModules.desktop-shell
        hardening.nixosModules.desktop-theme
        hardening.nixosModules.desktop-auto-update

        hardening.nixosModules.gpu-nvidia                # swap for gpu-amd as needed

        # ── Flake inputs that the framework modules expect ───────────
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence

        # ── Host-specific choices ────────────────────────────────────
        {
          # Wire home-manager in global-pkgs mode.
          home-manager = {
            useGlobalPkgs     = true;
            useUserPackages   = true;
            backupFileExtension = "bkp";
          };

          # System posture (only `daily` is active in this template).
          myOS.profile = "daily";
          myOS.gpu     = "nvidia";
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
            # homeManagerConfig = ./home/alice.nix;
            identity.git.name  = "Ada Lovelace";
            identity.git.email = "ada@example.com";
          };

          # Tracked file carries no identity. Put real values in a
          # gitignored override; see accounts/player.local.nix.example
          # in the upstream repo.
          # imports = [ ./identity.local.nix ];

          system.stateVersion = "26.05";
        }
      ];
    };
  };
}
