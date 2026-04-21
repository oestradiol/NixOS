# CUSTOMIZATION

This repo now ships a framework-owned storage baseline plus a thinner
template layer. The guiding rule is:

- framework modules own reusable policy
- templates own host/account composition
- local overrides should live in gitignored `*.local.nix`

## Common override surfaces

### `myOS.host.*`

Use for host identity and locale defaults:

- `myOS.host.hostName`
- `myOS.host.timeZone`
- `myOS.host.defaultLocale`

The reference template exposes `templates/default/hosts/nixos/local.nix`
as the gitignored place for these per-install edits.

### `myOS.users.<name>.*`

Use for account wiring:

- `activeOnProfiles`
- `allowWheel`
- `home.persistent`
- `home.btrfsSubvol`
- `homeManagerConfig`
- `identity.*`

Reference patterns:

- `templates/default/accounts/*.nix` for the two-account split
- `templates/workstation/flake.nix` for a single-user inline declaration

Identity and operator-local values belong in gitignored files such as:

- `templates/default/accounts/player.local.nix`
- `templates/default/accounts/ghost.local.nix`
- `templates/workstation/identity.local.nix`

### `myOS.storage.*`

The framework storage module lives at `modules/core/storage-layout.nix`.
Its defaults match the reference install layout:

- `myOS.storage.enable = true`
- `myOS.storage.devices.boot = "/dev/disk/by-label/NIXBOOT"`
- `myOS.storage.devices.cryptroot = "/dev/disk/by-partlabel/NIXCRYPT"`
- `myOS.storage.subvolumes.{nix,persist,log,swap}`
- `myOS.storage.rootTmpfs.{enable,size}`
- `myOS.storage.tmpTmpfs.{enable,size,options}`
- `myOS.storage.homeTmpfs.size`
- `myOS.storage.swap.{enable,sizeMiB}`

If your machine follows the default install conventions, you do not need
to edit storage at all.

If it differs, put overrides in a gitignored host-local file, for
example:

```nix
{ ... }:
{
  myOS.storage.devices.boot = "/dev/disk/by-label/MYBOOT";
  myOS.storage.devices.cryptroot = "/dev/disk/by-partlabel/MYCRYPT";
  myOS.storage.swap.enable = true;
}
```

### Full opt-out

If you need a completely custom filesystem layout, disable the framework
storage module and provide your own `fileSystems` / `swapDevices`:

```nix
{ ... }:
{
  myOS.storage.enable = false;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/...";
    fsType = "ext4";
  };
}
```

## Installer expectations

`scripts/rebuild-install.sh` now reads the selected flake/config instead
of assuming this repo's default template. It will:

- ask for the target flake path or URL
- resolve the pinned `hardening` source from that flake
- ask which framework template layout to follow
- ask which `nixosConfiguration` to install
- derive storage and password-hash targets from evaluated config

For the reference template, the easiest path is still to keep the
default storage labels and subvolume names.
