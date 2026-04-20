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
- impermanence-ready root (you still supply the disk layout)
- one permissive user on the `daily` posture (`allowWheel = true`,
  persistent home)

## What you still have to do

- supply a `hosts/<host>/fs-layout.nix` or equivalent matching your
  disk layout (the upstream reference at `templates/default/hosts/nixos/fs-layout.nix`
  is a good starting point)
- put real identity values in a gitignored override (see
  `templates/default/accounts/player.local.nix.example` upstream)
- decide whether to add the paranoid specialisation; if yes, copy the
  upstream `profiles/paranoid.nix` pattern

## Customising further

Every `myOS.*` option declared by the framework is documented in
`docs/CUSTOMIZATION.md` upstream. Cherry-pick additional
`hardening.nixosModules.*` entries to grow the surface.
