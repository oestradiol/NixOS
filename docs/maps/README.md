# Governance maps

Purpose: make the repo policy model explicit without collapsing the existing docs into one giant file.

Read in this order:
1. `PROFILE-POLICY.md`
2. `HARDENING-TRACKER.md`
3. `SOURCE-COVERAGE.md`

Use these files for:
- what `base`, `paranoid`, `daily`, `ghost`, and `player` mean
- which knobs are baseline, relaxed, staged, deferred, or rejected
- where each decision lives in code
- which external sources influenced the decision

Do not use this folder for installation steps. Operational flow stays in:
- `docs/pipeline/PRE-INSTALL.md`
- `docs/pipeline/INSTALL-GUIDE.md`
- `docs/pipeline/TEST-PLAN.md`
- `docs/pipeline/POST-STABILITY.md`
