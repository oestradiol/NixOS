# NixOS hardening repo

Single-host NixOS repo with one default hardened profile and one explicit daily specialization.

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
- security boundary map → `docs/maps/SECURITY-SURFACES.md`
- Nix import tree → `docs/maps/NIX-IMPORT-TREE.md`
- governance navigation → `docs/maps/README.md`

## Repo map
- architecture / policy / constraints / support boundary → `PROJECT-STATE.md`
- external source ledger → `REFERENCES.md`
- audit coverage / validation state / backlog → `docs/maps/AUDIT-STATUS.md`
- operational pipeline → `docs/pipeline/`
- host + profiles + modules → `hosts/`, `profiles/`, `modules/`
- helper scripts only → `scripts/`

## Stable-baseline rule
When the repo passes the current pre-install, install, and test-plan pipeline on the target machine, treat that as the first stable version.

After that point:
- keep using the machine from the stable baseline
- move all further tightening, experiments, and optional rollouts into `docs/pipeline/POST-STABILITY.md`
- do not mix deferred work back into the baseline path unless it is revalidated and moved into `docs/pipeline/TEST-PLAN.md`
