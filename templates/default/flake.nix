{
  description = "Operator's default workstation: full paranoid+daily with ghost+player";

  inputs = {
    nixpkgs.follows = "hardening/nixpkgs";
    home-manager.follows = "hardening/home-manager";
    stylix.follows = "hardening/stylix";
    impermanence.follows = "hardening/impermanence";
    lanzaboote.follows = "hardening/lanzaboote";
    agenix.follows = "hardening/agenix";
  
    # Framework as local path (or github:oestradiol/NixOS for external)
    hardening.url = "path:../..";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, stylix, impermanence, lanzaboote, agenix, hardening, ... }:
    let
      system = "x86_64-linux";
    in {
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
        hardening.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;

          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
          };
        }
      ];
    };
  };
}
