# Agent Entry Protocol — Dotfiles framework

This file is the entry protocol for agents beginning work in the Dotfiles
framework repo without prior context.

## First move

Read these in order:

1. `docs/governance/PROJECT-STATE.md`
2. `README.md`
3. `docs/maps/AUDIT-STATUS.md`
4. `docs/maps/README.md`
5. `docs/pipeline/INSTALL-GUIDE.md`
6. `docs/pipeline/TEST-PLAN.md`

If the task also edits a consuming configuration or another repo, open that
project's own entry surface from its root before changing it. Do not infer
external repo truth from this file.

## Operating stance

- treat this repo as the framework source of truth for hardening, profile
  machinery, and reusable NixOS substrate
- do not let deployment-local convenience rewrite framework boundaries
- preserve the distinction between stable baseline, staged features, and
  post-stability work
- prefer minimal, validated framework changes over speculative expansion

## Boundary rule

Cross-repo edits are allowed when the task truly crosses the boundary, but:

- framework rationale belongs here
- consumer-specific rationale belongs with the consuming config or repo
- validation should run in each touched repo
- commits should stay separated by repo

## Status

`dotfiles framework entry protocol`
