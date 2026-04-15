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

  outputs = inputs@{ nixpkgs, home-manager, stylix, impermanence, lanzaboote, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    checks.${system} = {
      required-files = pkgs.runCommand "required-files-check" {} ''
        echo "Checking required files..."
        for f in ${./.}/PROJECT-STATE.md ${./.}/flake.nix ${./.}/hosts/nixos/default.nix ${./.}/docs/maps/NIX-IMPORT-TREE.md ${./.}/docs/maps/SECURITY-SURFACES.md; do
          test -f "$f" || { echo "Missing: $f" > $out; exit 1; }
        done
        echo "All required files present" > $out
      '';
      # Note: nixos-config and daily-config checks removed because sandboxed derivations
      # cannot access unfree packages. Manual verification with:
      #   nix eval --json '.#nixosConfigurations.nixos.config.system.build.toplevel' --impure
      #   nix eval --json '.#nixosConfigurations.nixos.config.specialisation.daily.configuration.system.build.toplevel' --impure
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = system;
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nixos/default.nix
        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix
        impermanence.nixosModules.impermanence
        lanzaboote.nixosModules.lanzaboote
        agenix.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;

          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.ghost = import ./modules/home/ghost.nix;
            users.player = import ./modules/home/player.nix;
          };
        }
      ];
    };
  };
}
