{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # Bleeding-edge XR
    #nixpkgs-xr = {
    #  url = "github:nix-community/nixpkgs-xr";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, stylix, ... }: { #nixpkgs-xr,
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        stylix.nixosModules.stylix
        {
          #nixpkgs.overlays = [ nixpkgs-xr.overlays.default ];
          nixpkgs.config.allowUnfree = true;
          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            users.ruby = import ./modules/core/home.nix;
          };
        }
      ];
    };
  };
}
