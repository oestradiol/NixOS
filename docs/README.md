# Documentation

Central navigation for the NixOS hardening framework.

## Quick Start by Persona

Choose your path:

| I want to... | Start here |
|--------------|------------|
| Get a secure, private workstation with minimal effort | [`templates/workstation/`](../templates/workstation/) → [`pipeline/INSTALL-GUIDE.md`](pipeline/INSTALL-GUIDE.md) |
| Maximize privacy with paranoid+daily profile split | [`templates/default/`](../templates/default/) → [`pipeline/INSTALL-GUIDE.md`](pipeline/INSTALL-GUIDE.md) |
| Customize deeply / build my own template | [`CUSTOMIZATION.md`](CUSTOMIZATION.md) → [`maps/PROFILE-POLICY.md`](maps/PROFILE-POLICY.md) |
| Debug a problem or understand failures | [`pipeline/RECOVERY.md`](pipeline/RECOVERY.md) → [`guides/TROUBLESHOOTING.md`](guides/TROUBLESHOOTING.md) |
| Contribute or audit the framework | [`governance/PROJECT-STATE.md`](governance/PROJECT-STATE.md) → [`maps/AUDIT-STATUS.md`](maps/AUDIT-STATUS.md) |

## Document Map

### For Users

**Getting Started**
- [`templates/workstation/README.md`](../templates/workstation/README.md) — Minimal single-user daily template
- [`templates/default/README.md`](../templates/default/README.md) — Full paranoid+daily reference implementation
- [`pipeline/INSTALL-GUIDE.md`](pipeline/INSTALL-GUIDE.md) — Installation steps
- [`pipeline/TEST-PLAN.md`](pipeline/TEST-PLAN.md) — Validation checklist

**Customization**
- [`CUSTOMIZATION.md`](CUSTOMIZATION.md) — Framework options reference
- [`pipeline/RECOVERY.md`](pipeline/RECOVERY.md) — Rollback and repair
- [`guides/TROUBLESHOOTING.md`](guides/TROUBLESHOOTING.md) — Common issues and fixes

### For Framework Developers

**Architecture & Policy**
- [`governance/PROJECT-STATE.md`](governance/PROJECT-STATE.md) — Current architecture, boundaries, and non-claims
- [`maps/PROFILE-POLICY.md`](maps/PROFILE-POLICY.md) — Profile governance model (base/paranoid/daily)
- [`maps/HARDENING-TRACKER.md`](maps/HARDENING-TRACKER.md) — Every hardening knob and its state
- [`maps/FEATURES.md`](maps/FEATURES.md) — Complete feature inventory

**Verification & Audit**
- [`maps/AUDIT-STATUS.md`](maps/AUDIT-STATUS.md) — What's proven vs pending
- [`maps/SECURITY-SURFACES.md`](maps/SECURITY-SURFACES.md) — Security boundary inventory
- [`maps/SOURCE-COVERAGE.md`](maps/SOURCE-COVERAGE.md) — External source influence mapping
- [`pipeline/POST-STABILITY.md`](pipeline/POST-STABILITY.md) — Deferred work after baseline

**Scripts & Testing**
- [`../scripts/README.md`](../scripts/README.md) — Helper scripts reference
- [`../tests/README.md`](../tests/README.md) — Test suite documentation

## File Roles

| Folder | Purpose |
|--------|---------|
| `governance/` | Architecture, boundaries, invariants, project state |
| `maps/` | Reference documentation — hardening inventory, features, sources |
| `pipeline/` | Process documentation — install, test, recovery, deferred work |
| `guides/` | User-focused how-to and troubleshooting |

## Status Convention

Documents use these status terms consistently:

- `baseline` — Active now in shared base or paranoid
- `daily-softened` — Active in base/paranoid, explicitly weakened in daily
- `staged` — Implemented but off by default (needs explicit enable)
- `deferred` — Acknowledged follow-up, not baseline today
- `rejected` — Intentionally not part of this repo design

## Navigation Tips

- Start with the **Quick Start by Persona** table above
- Use **Ctrl+F** with status terms (`baseline`, `staged`, `deferred`) to find specific implementations
- Cross-references are explicit: `see maps/HARDENING-TRACKER.md`
- Every doc describes only its role and points elsewhere for the rest
