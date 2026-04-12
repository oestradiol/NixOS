# NixOS hardening repo

Two-profile NixOS host:
- `daily`: hardened within normal desktop usability constraints
- `paranoid`: hardened much more aggressively within explicit same-kernel and desktop-usability limits

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

## Repo map
- state / decisions / constraints → `PROJECT-STATE.md`
- references / external source ledger → `REFERENCES.md`
- audits / validations / pending audits → `AUDITS.md`
- install + operation docs → `docs/`
- NixOS code → `hosts/`, `profiles/`, `modules/`
- helper scripts → `scripts/`
