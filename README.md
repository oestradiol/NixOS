# NixOS hardening repo

Single-host NixOS repo with one default hardened profile and one explicit daily specialization.

This is a personal hardened-desktop configuration, not a distribution and not a turnkey template. It is designed to be **honest** about what it enforces, what is merely staged, and what remains the operator's responsibility. Read `docs/governance/PROJECT-STATE.md` before adapting any part of it to another machine.

## Current repo state
- `paranoid`: default hardened workstation baseline
- `daily`: boot specialization for gaming, social, and recovery-friendly use
- one installation, two users, one encrypted Btrfs/tmpfs-root system
- inactive profile home filesystems are not mounted; a boot-time invariant check verifies that the other profile's home mount is absent
- current stable target = complete `docs/pipeline/INSTALL-GUIDE.md` + `docs/pipeline/TEST-PLAN.md` on the real target machine
- `docs/pipeline/POST-STABILITY.md` is non-blocking follow-up work after the stable baseline is already usable on the machine

## Canonical profile policy
- `base`: shared hardening substrate only; not a standalone bootable profile
- `paranoid`: instantiates `base` for the `ghost` workstation with the strongest current workstation-safe hardening/privacy posture
- `daily`: instantiates `base` for the `player` workstation and softens only the controls needed for socialization, gaming, and recovery-friendly daily use
- `ghost` and `player`: the respective hardened and daily accounts

## Governance maps

Read in this order for policy model:
1. `docs/maps/PROFILE-POLICY.md`
2. `docs/maps/HARDENING-TRACKER.md`
3. `docs/maps/SOURCE-COVERAGE.md`

Use these files for:
- what `base`, `paranoid`, `daily`, `ghost`, and `player` mean
- which knobs are baseline, relaxed, staged, deferred, or rejected
- where each decision lives in code
- which external sources influenced the decision

## Truth surfaces
For agent entry, read `AGENTS.md` first.

Read in this order:
1. `PROJECT-STATE.md`
2. `REFERENCES.md`
3. `docs/maps/AUDIT-STATUS.md`
4. `docs/pipeline/INSTALL-GUIDE.md`
5. `docs/pipeline/TEST-PLAN.md`
6. `docs/pipeline/POST-STABILITY.md`
7. `docs/pipeline/RECOVERY.md`

## Code-derived maps
- feature inventory → `docs/maps/FEATURES.md`
- hardening knob ledger → `docs/maps/HARDENING-TRACKER.md`
- security boundary map → `docs/maps/SECURITY-SURFACES.md`
- source audit → `docs/maps/SOURCE-COVERAGE.md`

## Repo map
- architecture / policy / constraints / support boundary → `docs/governance/PROJECT-STATE.md`
- external source ledger → `REFERENCES.md`
- audit coverage / validation state / backlog → `docs/maps/AUDIT-STATUS.md`
- operational pipeline → `docs/pipeline/`
- host + profiles + modules → `hosts/`, `profiles/`, `modules/`
- test suite (static / runtime / bugs) → `tests/` (`tests/README.md`)
- helper scripts only → `scripts/`

## Framework consumption (Stage 6+)

This repo now exposes itself as a reusable NixOS framework. You can consume it without forking:

### A. Quickstart from template (new install)
```bash
nix flake init -t github:oestradiol/NixOS#workstation
# edit flake.nix for your hostName, GPU, user identity
sudo nixos-rebuild switch --flake .#workstation
```
See `templates/workstation/README.md` for the bootstrap checklist.

### B. Cherry-pick modules (existing flake)
Import only the hardening surface you need:
```nix
{
  inputs.hardening.url = "github:oestradiol/NixOS";
  outputs = { nixpkgs, hardening, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      modules = [
        hardening.nixosModules.core
        hardening.nixosModules.security-kernel-hardening
        hardening.nixosModules.desktop-plasma
        # ... your own modules
      ];
    };
  };
}
```
All 41 `nixosModules.*` outputs are documented in `flake.nix`.

### C. Fork-and-own (full adaptation)
Fork if you need to change framework internals (governance invariants, PAM binding experiments, browser wrappers). Keep the framework boundary clear: `modules/` and `profiles/` are the reusable substrate; `hosts/`, `accounts/`, and `accounts/*.local.nix` are your instance.

### Identity separation
Operator-specific values (git email, mic aliases, repo paths) live in gitignored `*.local.nix` files:
- `accounts/player.local.nix` (created from `accounts/player.local.nix.example`)
- `accounts/ghost.local.nix` (optional)
- `templates/default/hosts/nixos/local.nix` (system-level hardware quirks)

Tracked files contain only framework-level defaults and structural wiring.

## Operator-local overrides
`templates/default/hosts/nixos/default.nix` conditionally imports `local.nix` when that file exists. The path is **gitignored** and is the right place for per-install hardware quirks (external-drive UUIDs, experimental toggles, transient workarounds) that must never be published. If the file is absent, the import list is a no-op.

## Testing
The repo ships a three-layer test suite runnable offline:

```bash
./tests/run.sh                 # full sweep
./tests/run.sh --layer static  # eval + governance; no booted machine required
./tests/run.sh --layer runtime # probes the booted system
./tests/run.sh --layer bugs    # regressions for known historical bugs
```

See `tests/README.md` for per-file coverage.

## Stable-baseline rule
When the repo passes the current pre-install, install, and test-plan pipeline on the target machine, treat that as the first stable version.

After that point:
- keep using the machine from the stable baseline
- move all further tightening, experiments, and optional rollouts into `docs/pipeline/POST-STABILITY.md`
- do not mix deferred work back into the baseline path unless it is revalidated and moved into `docs/pipeline/TEST-PLAN.md`

## Code conventions

These are deliberate design choices, not debt. Do not "simplify" them.

- `lib.mkForce` in `profiles/daily.nix` is intentional — daily explicitly overrides the hardened base
- `networking.firewall.interfaces.<iface>.allowedUDPPorts = [ 9 ]` is WoL-over-UDP compatibility (see modules/security/networking.nix:16-29)
- `services.avahi.enable = lib.mkForce false` in modules/desktop/vr.nix is required because upstream wivrn.nix sets it without mkDefault
- `services.geoclue2.enable = lib.mkForce false` in modules/desktop/base.nix is required because Plasma 6 enables it via mkDefault
- `templates/default/hosts/nixos/default.nix` imports `local.nix` only via lib.optional (builtins.pathExists ./local.nix) — this is the sanctioned extension point for per-install hardware quirks
- `--show-trace` on every flake-* rebuild alias is debug-phase posture; drop once first fully-clean rebuild lands (HARDENING-TRACKER.md operator decision C1)

## What this repo does not claim
- wrapper isolation is not VM-equivalent; same-kernel containment only
- the desktop stack is not high assurance
- passing static review is not runtime proof
- staged features (see `HARDENING-TRACKER.md`) are not part of the baseline until explicitly graduated
