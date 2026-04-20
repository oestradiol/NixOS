# Agent Entry Protocol — Dotfiles framework

This file is the entry protocol for agents beginning work in the Dotfiles
framework repo without prior context.

## First move

Read these in order:

1. `PROJECT-STATE.md`
2. `README.md`
3. `docs/maps/AUDIT-STATUS.md`
4. `docs/maps/README.md`
5. `docs/pipeline/PRE-INSTALL.md`
6. `docs/pipeline/INSTALL-GUIDE.md`
7. `docs/pipeline/TEST-PLAN.md`

If the task crosses the framework / instance / workspace boundary, also read:

- `../REPO_STRUCTURE.md`
- `../Governance/README.md`
- `../Governance/docs/WORKSPACE_OPERATING_MODEL.md`
- `../Tools/README.md`
- `../AKS/docs/INSTANCE-MODEL.md`
- `../AKS/docs/FRAMEWORK-DEPENDENCY.md`

## Operating stance

- treat this repo as the framework source of truth for hardening, profile
  machinery, and reusable NixOS substrate
- do not let instance-local convenience rewrite framework boundaries
- preserve the distinction between stable baseline, staged features, and
  post-stability work
- prefer minimal, validated framework changes over speculative expansion

## Boundary rule

Cross-repo edits are allowed when the task truly crosses the boundary, but:

- framework rationale belongs here
- instance rationale belongs in the instance repo
- validation should run in each touched repo
- commits should stay separated by repo

## Status

`dotfiles framework entry protocol`
