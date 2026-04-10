{
  description = "NixOS: one install, two boot specialisations, daily + paranoid";

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

    impermanence.url = "github:nix-community/impermanence";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, stylix, impermanence, agenix, lanzaboote, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nixos/default.nix
        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix
        impermanence.nixosModules.impermanence
        agenix.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        {
          nixpkgs.config.allowUnfree = true;

          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.player = import ./modules/home/daily.nix;
            users.ghost = import ./modules/home/paranoid.nix;
          };
        }
      ];
    };
  };
}
