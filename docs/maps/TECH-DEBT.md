# Technical Debt

Temporary scaffolding and workarounds that will be removed or replaced.
For deferred features and post-stability work, see POST-STABILITY.md.
For staged features, see HARDENING-TRACKER.md.

## Current scaffolding

None. All temporary scaffolding has been removed or promoted to appropriate documents.

## Design notes (not debt, but worth keeping)

These are deliberate design choices, not debt. Do not "simplify" them.

- `lib.mkForce` in `profiles/daily.nix` is intentional — daily explicitly overrides the hardened base
- `networking.firewall.interfaces.<iface>.allowedUDPPorts = [ 9 ]` is WoL-over-UDP compatibility (see modules/security/networking.nix:16-29)
- `services.avahi.enable = lib.mkForce false` in modules/desktop/vr.nix is required because upstream wivrn.nix sets it without mkDefault
- `services.geoclue2.enable = lib.mkForce false` in modules/desktop/base.nix is required because Plasma 6 enables it via mkDefault
- `hosts/nixos/default.nix` imports `hosts/nixos/local.nix` only via lib.optional (builtins.pathExists ./local.nix) — this is the sanctioned extension point for per-install hardware quirks
- `--show-trace` on every flake-* rebuild alias is debug-phase posture; drop once first fully-clean rebuild lands (HARDENING-TRACKER.md operator decision C1)
