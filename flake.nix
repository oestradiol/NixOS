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

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, stylix, impermanence, agenix, lanzaboote, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    # Build-time checks for nix flake check
    # These verify the NixOS configurations evaluate correctly
    checks.${system} = {
      # Verify required files exist
      required-files = pkgs.runCommand "required-files-check" {} ''
        echo "Checking required files..."
        for f in ${./.}/PROJECT-STATE.md ${./.}/flake.nix ${./.}/hosts/nixos/default.nix; do
          test -f "$f" || { echo "Missing: $f" > $out; exit 1; }
        done
        echo "All required files present" > $out
      '';

      # Verify nixos configuration evaluates
      nixos-config = pkgs.runCommand "nixos-config-check"
        { nativeBuildInputs = [ pkgs.nix ]; }
        ''
          echo "Evaluating nixos configuration..."
          nix eval --json '.#nixosConfigurations.nixos.config.system.build.toplevel' \
            --store /tmp/empty-store 2>/dev/null \
            || { echo "nixos config evaluation failed"; exit 1; }
          echo "nixos config evaluates successfully" > $out
        '';

      # Verify paranoid specialisation builds
      paranoid-config = pkgs.runCommand "paranoid-config-check"
        { nativeBuildInputs = [ pkgs.nix ]; }
        ''
          echo "Checking paranoid specialisation..."
          # Evaluate the paranoid specialisation toplevel
          nix eval --json '.#nixosConfigurations.nixos.config.specialisation.paranoid.configuration.system.build.toplevel' \
            --store /tmp/empty-store 2>/dev/null \
            || { echo "paranoid specialisation evaluation failed"; exit 1; }
          echo "paranoid specialisation evaluates successfully" > $out
        '';
    };

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
          nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkg.pname or pkg.name) [
            # NVIDIA drivers (unfree, required for GTX 1060)
            "nvidia-x11"
            "nvidia-settings"
            # Steam (unfree, daily profile gaming)
            "steam"
            "steam-original"
            "steam-run"
            # Gamescope (unfree, Steam compositor)
            "gamescope"
          ];

          home-manager = {
            backupFileExtension = "bkp";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.player = import ./modules/home/player.nix;
            users.ghost = import ./modules/home/ghost.nix;
          };
        }
      ];
    };
  };
}
