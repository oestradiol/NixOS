# AGENTS

LLM/assistant handoff only.

## Read order
1. `README.md`
2. `PROJECT-STATE.md`
3. `REFERENCES.md`
4. `AUDITS.md`
5. the specific operational doc you need in `docs/`
6. code

## Canonical routing
- front door only → `README.md`
- repo state / architecture / decisions / constraints → `PROJECT-STATE.md`
- references / external source ledger → `REFERENCES.md`
- audits / validations / pending audits → `AUDITS.md`
- pre-install checks only → `docs/PRE-INSTALL.md`
- install steps only → `docs/INSTALL-GUIDE.md`
- current validation only → `docs/TEST-PLAN.md`
- deferred work only → `docs/POST-STABILITY.md`
- recovery only → `docs/RECOVERY.md`
- performance only → `docs/PERFORMANCE-NOTES.md`

## Status vocabulary
- implemented
- implemented+manual
- deferred
- rejected
- static-only
- runtime-validated

## Working rules
- do not overclaim wrapper strength
- do not call unfinished work complete
- preserve losslessness when compressing docs: move or cross-reference, do not silently drop
- anything unfinished must exist on the pipeline somewhere canonical
- daily = hardened within usability constraints
- paranoid = hardened within paranoid constraints, with explicit same-kernel and usability limits

## Useful repo facts
- Firefox hardening is maintained in-repo as an arkenfox-derived baseline with explicit daily overrides
- Tor Browser and Mullvad Browser keep upstream browser hardening; repo adds local wrapper containment
- paranoid WireGuard requires pinned literal endpoint `IP:port`
- VM tooling lives in `modules/security/vm-tooling.nix`; four VM workflow classes and six policy layers are defined in `PROJECT-STATE.md`, and host-side automation now ships through repo-managed networks plus `repo-vm-class`
- wrapper seccomp and Landlock remain deferred

- paranoid audit means the Linux audit subsystem, auditd, and a repo rule set
- AppArmor currently means framework + D-Bus mediation baseline, not a finished custom policy library
- `networking.wireguard` is intentionally kept for now; move only if live routing/MTU issues justify it
- `REFERENCES.md` is the canonical external-source ledger; full archival capture is still deferred
