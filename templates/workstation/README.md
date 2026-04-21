# workstation template

Minimal single-host workstation using the `oestradiol/NixOS` framework
as a flake input. Starting point for integrators who do **not** want
the upstream repo's paranoid + daily specialisation split.

## Bootstrap

```bash
nix flake init -t github:oestradiol/NixOS#workstation
$EDITOR flake.nix               # hostName, GPU, user identity
sudo nixos-rebuild switch --flake .#workstation
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
