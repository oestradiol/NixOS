{
  description = "Operator's default workstation: full paranoid+daily with ghost+player";

  inputs = {
    # Framework via relative path.
    # If you fork/copy this template, update to absolute path or use builtins.getEnv.
    hardening.url = "path:../..";
  };

  outputs = inputs@{ self, hardening, ... }:
    let
      # Merge hardening.inputs into inputs for host file compatibility
      allInputs = inputs // hardening.inputs;
      system = "x86_64-linux";
    in with allInputs; {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = system;
      specialArgs = { inputs = allInputs; };
      modules = [
        ./hosts/nixos/default.nix
        allInputs.home-manager.nixosModules.home-manager
        allInputs.stylix.nixosModules.stylix
        allInputs.impermanence.nixosModules.impermanence
        allInputs.lanzaboote.nixosModules.lanzaboote
        allInputs.agenix.nixosModules.default
        allInputs.hardening.nixosModules.default
        {
          nixpkgs.config.allowUnfree = true;

          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inputs = allInputs; };
          };
        }
      ];
    };
  };
}
