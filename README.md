# NixOS hardening repo

Single-host NixOS repo with one default hardened profile and one explicit daily specialization.

This is a personal hardened-desktop configuration, not a distribution and not a turnkey template. It is designed to be **honest** about what it enforces, what is merely staged, and what remains the operator's responsibility. Read `PROJECT-STATE.md` before adapting any part of it to another machine.

## Current repo state
- `paranoid`: default hardened workstation baseline
- `daily`: boot specialization for gaming, social, and recovery-friendly use
- one installation, two users, one encrypted Btrfs/tmpfs-root system
- inactive profile home filesystems are not mounted; a boot-time invariant check verifies that the other profile's home mount is absent
- current stable target = complete `docs/pipeline/PRE-INSTALL.md` + `docs/pipeline/INSTALL-GUIDE.md` + `docs/pipeline/TEST-PLAN.md` on the real target machine
- `docs/pipeline/POST-STABILITY.md` is non-blocking follow-up work after the stable baseline is already usable on the machine

## Canonical profile policy
- `base`: shared hardening substrate only; not a standalone bootable profile
- `paranoid`: instantiates `base` for the `ghost` workstation with the strongest current workstation-safe hardening/privacy posture
- `daily`: instantiates `base` for the `player` workstation and softens only the controls needed for socialization, gaming, and recovery-friendly daily use
- `ghost` and `player`: the respective hardened and daily accounts
- governance map for every major knob and source influence → `docs/maps/README.md`

## Truth surfaces
Read in this order:
1. `PROJECT-STATE.md`
2. `REFERENCES.md`
3. `docs/maps/AUDIT-STATUS.md`
4. `docs/pipeline/PRE-INSTALL.md`
5. `docs/pipeline/INSTALL-GUIDE.md`
6. `docs/pipeline/TEST-PLAN.md`
7. `docs/maps/README.md`
8. `docs/pipeline/POST-STABILITY.md`
9. `docs/pipeline/RECOVERY.md`
10. `docs/maps/PERFORMANCE-NOTES.md`

## Code-derived maps
- feature inventory → `docs/maps/FEATURES.md`
- hardening knob ledger → `docs/maps/HARDENING-TRACKER.md`
- security boundary map → `docs/maps/SECURITY-SURFACES.md`
- Nix import tree → `docs/maps/NIX-IMPORT-TREE.md`
- open technical debt (commented code, staged knobs, deferred decisions) → `docs/maps/TECH-DEBT.md`
- governance navigation → `docs/maps/README.md`

## Repo map
- architecture / policy / constraints / support boundary → `PROJECT-STATE.md`
- external source ledger → `REFERENCES.md`
- audit coverage / validation state / backlog → `docs/maps/AUDIT-STATUS.md`
- operational pipeline → `docs/pipeline/`
- host + profiles + modules → `hosts/`, `profiles/`, `modules/`
- test suite (static / runtime / bugs) → `tests/` (`tests/README.md`)
- helper scripts only → `scripts/`

## Operator-local overrides
`hosts/nixos/default.nix` conditionally imports `hosts/nixos/local.nix` when that file exists. The path is **gitignored** and is the right place for per-install hardware quirks (external-drive UUIDs, experimental toggles, transient workarounds) that must never be published. If the file is absent, the import list is a no-op.

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

## What this repo does not claim
- wrapper isolation is not VM-equivalent; same-kernel containment only
- the desktop stack is not high assurance
- passing static review is not runtime proof
- staged features (see `TECH-DEBT.md` §3) are not part of the baseline until explicitly graduated
