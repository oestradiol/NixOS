# workstation template

Minimal single-host workstation using the `oestradiol/NixOS` framework
as a flake input. Starting point for integrators who do **not** want
the upstream repo's paranoid + daily specialisation split.

## Bootstrap

### Quick Start (Existing NixOS System)

If you already have NixOS installed and want to switch to this framework:

```bash
nix flake init -t github:oestradiol/NixOS#workstation
$EDITOR flake.nix               # hostName, GPU, user identity
sudo nixos-rebuild switch --flake .#workstation
```

### New Install (From NixOS Installer ISO)

Use the guided install script:

```bash
# From NixOS installer, fetch and run the install script
curl -L -o rebuild-install.sh https://raw.githubusercontent.com/oestradiol/NixOS/main/scripts/rebuild-install.sh
chmod +x rebuild-install.sh
sudo ./rebuild-install.sh

# The script will:
# - Ask for this template (templates/workstation)
# - Ask for the workstation nixosConfiguration
# - Format disk (EFI + LUKS + Btrfs)
# - Generate hardware config
# - Prompt for user password
# - Run nixos-install
```

See `docs/pipeline/INSTALL-GUIDE.md` for detailed phase-by-phase documentation.

### Manual Install

If you prefer manual control over the install process:

```bash
# 1. Partition: EFI + LUKS2 root
# 2. Open LUKS and create Btrfs filesystem
# 3. Create subvolumes: @nix, @persist, @log
# 4. Mount tmpfs root and Btrfs subvolumes
# 5. Stage this template to /mnt/etc/nixos
# 6. Generate hardware-target.nix
# 7. nixos-install --flake /mnt/etc/nixos#workstation

# See INSTALL-GUIDE.md for full manual steps
```

## What you get

- NixOS 26.05 baseline with the framework's hardening substrate
- Plasma 6 on greetd, safe-firefox sandbox, flatpak, ClamAV + AIDE
- the framework-owned storage baseline by default:
  LUKS root, tmpfs `/`, Btrfs `/nix` + `/persist` + `/var/log`, optional
  disk-backed swap, and per-user home mounts derived from `myOS.users.*`
- one permissive user on the `daily` posture (`allowWheel = true`,
  persistent home)

## What you still have to do

- keep the install conventions if you want zero storage edits:
  `NIXBOOT`, `NIXCRYPT`, and the default `@nix` / `@persist` / `@log`
  subvolumes
- or override storage through `myOS.storage.*` in `local.nix`
- put real identity values in the gitignored `identity.local.nix`
- decide whether to add the paranoid specialisation; if yes, copy the
  upstream `profiles/paranoid.nix` pattern

## Customising further

Every `myOS.*` option declared by the framework is documented in
`docs/CUSTOMIZATION.md` upstream. The template ships example overrides:

- `hardware-target.nix.example`
- `identity.local.nix.example`
- `local.nix.example`

Cherry-pick additional `hardening.nixosModules.*` entries to grow the
surface.
