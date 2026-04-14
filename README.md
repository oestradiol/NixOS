# NixOS hardening repo

Single-host NixOS repo with one default hardened profile and one explicit daily specialization.

## Current repo state
- `paranoid`: default hardened workstation baseline
- `daily`: boot specialization for gaming, social, and recovery-friendly use
- one installation, two users, one encrypted Btrfs/tmpfs-root system
- current stable target = complete `docs/PRE-INSTALL.md` + `docs/INSTALL-GUIDE.md` + `docs/TEST-PLAN.md`
- `docs/POST-STABILITY.md` is non-blocking follow-up work after the stable baseline is already usable on the machine

## Truth surfaces
Read in this order:
1. `PROJECT-STATE.md`
2. `REFERENCES.md`
3. `AUDITS.md`
4. `docs/PRE-INSTALL.md`
5. `docs/INSTALL-GUIDE.md`
6. `docs/TEST-PLAN.md`
7. `docs/POST-STABILITY.md`
8. `docs/RECOVERY.md`
9. `docs/PERFORMANCE-NOTES.md`

## Code-derived maps
- security boundary map → `docs/SECURITY-SURFACES.md`
- Nix import tree → `docs/NIX-IMPORT-TREE.md`

## Repo map
- architecture / policy / constraints / support boundary → `PROJECT-STATE.md`
- external source ledger → `REFERENCES.md`
- audit coverage / validation state / backlog → `AUDITS.md`
- operational pipeline → `docs/`
- host + profiles + modules → `hosts/`, `profiles/`, `modules/`
- helper scripts only → `scripts/`

## Stable-baseline rule
When the repo passes the current pre-install, install, and test-plan pipeline on the target machine, treat that as the first stable version.

After that point:
- keep using the machine from the stable baseline
- move all further tightening, experiments, and optional rollouts into `docs/POST-STABILITY.md`
- do not mix deferred work back into the baseline path unless it is revalidated and moved into `docs/TEST-PLAN.md`
