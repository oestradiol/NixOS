# REFERENCES

Canonical reference ledger for external sources, validation targets, and archive status.

## Purpose
- single place for the repo's external reference set
- track what each source is used for
- record archive/capture status
- show where each source affects code or docs
- make future re-audits and assistant handoff easier

## Structure
Each entry should track:
- tier: primary / strong-secondary / cautionary
- topic
- source
- what the repo uses it for
- archive status
- repo surfaces influenced
- current status

## Current state
This file now exists as the canonical reference surface, but archive capture is not yet complete.
High-tier structuring is present; full archival snapshots, per-claim section pinning, and immutable capture are still deferred.
Until that is done, `AUDITS.md` remains the operational audit ledger and this file remains the canonical reference index.

## High-tier reference set

| tier | topic | source | use in repo | archive status | repo surfaces | status |
|---|---|---|---|---|---|---|
| primary | NixOS options/manual | NixOS manual, option search, MyNixOS | exact option semantics and module expectations | partial live-link only | code + docs repo-wide | active |
| primary | NixOS operational guidance | NixOS Wiki | installation and service-specific operational guidance | partial live-link only | install, WireGuard, fwupd, Btrfs, networking | active |
| primary | Firefox hardening baseline | arkenfox | vendored Firefox hardening baseline and override model | vendored snapshot present | `modules/security/browser.nix`, `modules/security/arkenfox/user.js` | active |
| primary | VM/libvirt policy | libvirt domain/network docs, virt-install docs, SPICE docs | VM classes, host/guest boundary defaults, launcher behavior | partial live-link only | `modules/security/vm-tooling.nix`, `PROJECT-STATE.md`, `docs/TEST-PLAN.md`, `docs/POST-STABILITY.md` | active |
| strong-secondary | NixOS hardening model | saylessss88 NixOS hardening guide | profile split and NixOS-oriented hardening review | live-link only | `AUDITS.md`, `PROJECT-STATE.md` | active |
| strong-secondary | Linux hardening model | Madaidan Linux hardening guide | threat-model-driven hardening, kernel/service posture | live-link only | `PROJECT-STATE.md`, `modules/core/boot.nix`, `modules/security/base.nix`, `modules/core/options.nix` | active |
| strong-secondary | Linux hardening checklist | Trimstray Linux hardening guide | practical checklist cross-checks | live-link only | `AUDITS.md`, `PROJECT-STATE.md` | active |

## Topic notes

### Audit
Use NixOS option references plus operational validation. Repo claim should stay limited to what the configured audit subsystem and rule set actually provide.

### AppArmor
Use NixOS option references for framework semantics. Current repo state is framework + D-Bus mediation baseline, with repo-maintained profiles deferred. `killUnconfinedConfinables` remains a post-stability decision because upstream docs warn it changes process-handling behavior after policy introduction.

### WireGuard
Use NixOS options/wiki as the main source. Current repo decision keeps `networking.wireguard` and defers `systemd.network` migration evaluation to post-stability unless live validation shows routing, DNS, MTU, or interface-ordering problems.

### VM workflow
Use libvirt/virt-install/SPICE docs as the main source. Current repo has host-side automation and class policy, but guest templates and real-world tuning still need live trials.

### Browser hardening
Use arkenfox for Firefox baseline, and keep Tor Browser / Mullvad Browser aligned with their upstream privacy model rather than forcing arkenfox onto them.

## Crosslinks
- audit conclusions and validation status: `AUDITS.md`
- repo decisions and support boundaries: `PROJECT-STATE.md`
- install/test/recovery actions: `docs/`
- assistant routing: `AGENTS.md`

## Deferred reference-work
Move these to post-stability governance work:
- archive every high-tier source into an immutable capture set
- pin important claims to exact section/header/anchor
- maintain a stronger claim-to-reference registry with freshness dates
- add consistency checks so docs/code/audits/reference ledger cannot drift silently
