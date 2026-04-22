# NixOS hardening framework

A composable, production-ready NixOS hardening framework with orthogonal profile+user axes.

**Not a distribution** — this is a library of hardening modules plus reference templates. It is designed to be **honest** about what it enforces, what is merely staged, and what remains the operator's responsibility.

## Quick Start by Persona

| I want... | Start here | Template |
|-----------|------------|----------|
| A secure, private Linux workstation with minimal effort | [`templates/workstation/README.md`](templates/workstation/README.md) | Single-user daily profile |
| Maximum privacy with paranoid+daily split | [`templates/default/README.md`](templates/default/README.md) | Two-user paranoid+daily |
| Deep customization / my own template | [`docs/CUSTOMIZATION.md`](docs/CUSTOMIZATION.md) + [`docs/maps/PROFILE-POLICY.md`](docs/maps/PROFILE-POLICY.md) | Build your own |
| To debug issues or fix failures | [`docs/pipeline/RECOVERY.md`](docs/pipeline/RECOVERY.md) + [`docs/guides/TROUBLESHOOTING.md`](docs/guides/TROUBLESHOOTING.md) | Any |

**New users**: Start with the workstation template for fastest path to a hardened system.
**Privacy-focused users**: Use the default template for paranoid profile isolation.

Read [`docs/governance/PROJECT-STATE.md`](docs/governance/PROJECT-STATE.md) before adapting any part to another machine.

## Current repo state
- `paranoid`: default hardened workstation baseline
- `daily`: boot specialization for gaming, social, and recovery-friendly use
- orthogonal profile+user axes: profiles define system posture, users define identity/persistence
- one encrypted Btrfs/tmpfs-root system with cross-profile mount isolation
- current stable target = complete `docs/pipeline/INSTALL-GUIDE.md` + `docs/pipeline/TEST-PLAN.md` on the real target machine
- `docs/pipeline/POST-STABILITY.md` is non-blocking follow-up work after the stable baseline is already usable on the machine

## Canonical profile policy
- `base`: shared hardening substrate only; not a standalone bootable profile
- `paranoid`: strongest workstation-safe hardening/privacy posture (staged as `nixosModules.profile-paranoid`)
- `daily`: softens only the controls needed for socialization, gaming, and recovery-friendly daily use (staged as `nixosModules.profile-daily`)
- Users are declared via `myOS.users.<name>` with `activeOnProfiles` determining profile bindings
- The default template demonstrates one daily-style user (persistent home, wheel) + one paranoid-style user (tmpfs home, no wheel)

## Documentation map

**Navigation hub**: [`docs/README.md`](docs/README.md) — central index of all documentation.

### For users (getting started)
1. [`templates/workstation/README.md`](templates/workstation/README.md) or [`templates/default/README.md`](templates/default/README.md)
2. [`docs/pipeline/INSTALL-GUIDE.md`](docs/pipeline/INSTALL-GUIDE.md)
3. [`docs/CUSTOMIZATION.md`](docs/CUSTOMIZATION.md)
4. [`docs/pipeline/RECOVERY.md`](docs/pipeline/RECOVERY.md) + [`docs/guides/TROUBLESHOOTING.md`](docs/guides/TROUBLESHOOTING.md)

### For framework developers (understanding the system)

**Policy model** (read in order):
1. [`docs/maps/PROFILE-POLICY.md`](docs/maps/PROFILE-POLICY.md) — Profile governance (base/paranoid/daily)
2. [`docs/maps/HARDENING-TRACKER.md`](docs/maps/HARDENING-TRACKER.md) — Every hardening knob and its state
3. [`docs/maps/SOURCE-COVERAGE.md`](docs/maps/SOURCE-COVERAGE.md) — External source influence mapping

**Verification**:
- [`docs/maps/AUDIT-STATUS.md`](docs/maps/AUDIT-STATUS.md) — What's proven vs pending
- [`docs/maps/FEATURES.md`](docs/maps/FEATURES.md) — Complete feature inventory
- [`docs/pipeline/TEST-PLAN.md`](docs/pipeline/TEST-PLAN.md) — Validation checklist
- [`docs/pipeline/POST-STABILITY.md`](docs/pipeline/POST-STABILITY.md) — Deferred work after baseline

## For agents (automated entry)

For agent/AI entry, read `AGENTS.md` first, then:
1. [`docs/governance/PROJECT-STATE.md`](docs/governance/PROJECT-STATE.md)
2. `REFERENCES.md`
3. [`docs/maps/AUDIT-STATUS.md`](docs/maps/AUDIT-STATUS.md)
4. [`docs/pipeline/INSTALL-GUIDE.md`](docs/pipeline/INSTALL-GUIDE.md)
5. [`docs/pipeline/TEST-PLAN.md`](docs/pipeline/TEST-PLAN.md)
6. [`docs/pipeline/POST-STABILITY.md`](docs/pipeline/POST-STABILITY.md)
7. [`docs/pipeline/RECOVERY.md`](docs/pipeline/RECOVERY.md)

## Repo structure

| Path | Purpose |
|------|---------|
| `modules/`, `profiles/` | Framework library (reusable NixOS modules) |
| `templates/default/` | Reference implementation (paranoid+daily split) |
| `templates/workstation/` | Minimal single-user template |
| `docs/` | Documentation hub |
| `tests/` | Test suite (`tests/run.sh`) |
| `scripts/` | Helper scripts only |
| `flake.nix` | Framework exports (40 `nixosModules.*` outputs) |

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
All 40 `nixosModules.*` outputs are documented in `flake.nix`.

### C. Fork-and-own (full adaptation)
Fork if you need to change framework internals (governance invariants, PAM binding experiments, browser wrappers). Keep the framework boundary clear: `modules/` and `profiles/` are the reusable substrate; `templates/default/hosts/`, `templates/default/accounts/`, and `*.local.nix` are your instance.

### Identity separation
Operator-specific values (git email, mic aliases, repo paths) live in gitignored `*.local.nix` files alongside the tracked account definitions:
- `templates/default/accounts/*.local.nix` (per-account identity; the default template demonstrates this pattern)
- `templates/default/hosts/nixos/local.nix` (system-level hardware quirks)

Tracked files contain only framework-level defaults and structural wiring. Forks may use any user naming scheme.

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
