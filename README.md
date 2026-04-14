# NixOS hardening repo

Two-profile NixOS host:
- `paranoid`: default hardened workstation baseline with explicit documented residual surfaces
- `daily`: boot specialization that intentionally relaxes selected controls for gaming/social compatibility

## Read order
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
- state / decisions / constraints → `PROJECT-STATE.md`
- references / external source ledger → `REFERENCES.md`
- audits / validations / pending audits → `AUDITS.md`
- install + operation docs → `docs/`
- NixOS code → `hosts/`, `profiles/`, `modules/`
- helper scripts → `scripts/`
