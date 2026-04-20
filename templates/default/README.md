# default template

The reference implementation of the `oestradiol/NixOS` framework — a hardened
NixOS workstation with paranoid/daily profile separation.

## What is this?

This template demonstrates the framework's intended use: a single NixOS
installation with two boot profiles sharing a hardened base:

- **`paranoid`** (default): Hardened workstation for the `ghost` user
  - tmpfs root with selective persistence
  - Full hardening: bubblewrapped browsers, strict sandboxing, auditd
  - Safe Firefox with arkenfox profile
  
- **`daily`** (specialisation): Relaxed profile for the `player` user
  - Gaming, social, recovery-friendly use
  - Persistent home directory
  - Standard Firefox, Flatpak, VR support

## Directory structure

```
templates/default/
├── flake.nix              # Entry point: nixosConfigurations.nixos
├── hosts/nixos/           # Host-specific configuration
│   ├── default.nix        # Main host config, imports profiles
│   ├── fs-layout.nix      # Disk/partition layout
│   ├── hardware-target.nix # CPU, kernel modules, firmware
│   └── local.nix.example  # Template for local overrides
└── accounts/              # User account definitions
    ├── ghost.nix          # Paranoid profile user
    ├── player.nix         # Daily profile user
    ├── home/              # Home-manager configurations
    │   ├── ghost.nix
    │   └── player.nix
    └── *.local.nix.example # Templates for identity overrides
```

## Quick start (for this repo's maintainer)

This template is already wired into the framework flake. To build:

```bash
# From repo root
sudo nixos-rebuild switch --flake .#nixos
```

The `nixos` configuration uses this template by default.

## Forking/adapting this template

To use this as a starting point for your own machine:

1. **Copy the template** to your own flake repo:
   ```bash
   cp -r templates/default/* /your/new/nixos-config/
   ```

2. **Edit identity files** (create from examples):
   ```bash
   cp templates/default/accounts/player.local.nix.example \
      /your/config/accounts/player.local.nix
   # Edit: git email, user name, any personal paths
   ```

3. **Configure disk layout** in `hosts/nixos/fs-layout.nix`:
   - Update LUKS device UUIDs
   - Adjust Btrfs subvolume layout for your disks

4. **Adjust hardware** in `hosts/nixos/hardware-target.nix`:
   - CPU microcode (AMD vs Intel)
   - Kernel modules for your hardware

5. **Optional**: Rename accounts, add/remove users

## Framework boundary

Files in this directory are **instance-specific**:
- User identities (`accounts/*.local.nix`)
- Disk UUIDs and hardware quirks (`hosts/nixos/local.nix`)
- Hostname and system-specific wiring

Framework code (reusable across instances) lives at repo root:
- `modules/` — NixOS modules library
- `profiles/` — paranoid/daily profile definitions
- `lib/` — shared functions and builders

## Relationship to workstation template

- `templates/default/` — This repo's actual machine (paranoid + daily)
- `templates/workstation/` — Minimal starter for integrators who want
  only the daily profile without the paranoid/daily split

## See also

- Framework options: `docs/CUSTOMIZATION.md`
- Installation: `docs/pipeline/INSTALL-GUIDE.md`
- Policy: `docs/maps/PROFILE-POLICY.md`
