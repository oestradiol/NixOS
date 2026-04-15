# Nix import tree

Manually refreshed from the current source tree after the security-base refactor. This file describes actual local imports in the checked-in repo state.

## Recursive tree

- `flake.nix`
  - module list entry: `hosts/nixos/default.nix`
    - `hosts/nixos/default.nix`
      - module list entry: `hosts/nixos/fs-layout.nix`
      - module list entry: `hosts/nixos/hardware-target.nix`
        - external import: `modulesPath + "/installer/scan/not-detected.nix"`
      - module list entry: `modules/core/options.nix`
      - module list entry: `modules/core/boot.nix`
      - module list entry: `modules/core/users.nix`
      - module list entry: `modules/desktop/base.nix`
        - module list entry: `modules/desktop/theme.nix`
      - module list entry: `modules/security/base.nix`
        - module list entry: `modules/security/governance.nix`
        - module list entry: `modules/security/networking.nix`
        - module list entry: `modules/security/wireguard.nix`
        - module list entry: `modules/security/browser.nix`
          - direct import: `modules/security/sandbox-core.nix`
        - module list entry: `modules/security/impermanence.nix`
        - module list entry: `modules/security/secrets.nix`
        - module list entry: `modules/security/secure-boot.nix`
        - module list entry: `modules/security/flatpak.nix`
        - module list entry: `modules/security/scanners.nix`
        - module list entry: `modules/security/vm-tooling.nix`
        - module list entry: `modules/security/sandboxed-apps.nix`
          - direct import: `modules/security/sandbox-core.nix`
        - module list entry: `modules/security/privacy.nix`
        - module list entry: `modules/security/user-profile-binding.nix`
      - module list entry: `modules/gpu/nvidia.nix`
      - module list entry: `modules/gpu/amd.nix`
      - module list entry: `profiles/paranoid.nix`
      - specialisation import: `profiles/daily.nix`
        - module list entry: `modules/desktop/gaming.nix`
          - module list entry: `modules/desktop/vr.nix`
          - module list entry: `modules/desktop/controllers.nix`
  - flake input module: `home-manager.nixosModules.home-manager`
  - flake input module: `stylix.nixosModules.stylix`
  - flake input module: `impermanence.nixosModules.impermanence`
  - flake input module: `lanzaboote.nixosModules.lanzaboote`
  - flake input module: `agenix.nixosModules.default`
  - Home Manager user import: `modules/home/ghost.nix`
    - module list entry: `modules/home/common.nix`
      - module list entry: `modules/desktop/shell.nix`
  - Home Manager user import: `modules/home/player.nix`
    - module list entry: `modules/home/common.nix`
      - module list entry: `modules/desktop/shell.nix`
