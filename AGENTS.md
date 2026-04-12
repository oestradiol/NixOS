# Repository Guide

This file is for repository-aware tools and for future handoff work. Human-first.

## Purpose
Governed NixOS hardening repo. One host, two trust tiers: `daily` and `paranoid`.
Goal: keep code, docs, and audit surfaces aligned.

## Read in this order
1. `PROJECT-STATE.md`
2. `docs/audit/SOURCE-TOPIC-LEDGER.md`
3. `docs/PRE-INSTALL.md`

## Canonical rules
- Frozen decisions live in `PROJECT-STATE.md`.
- Topic coverage lives in `docs/audit/SOURCE-TOPIC-LEDGER.md`.
- If code changes behavior, update docs in the same commit.
- Never commit real secrets. `secrets/` is scaffolding only.

## Truthfulness rules
- Do not claim a feature is implemented unless code exists for it.
- Preserve the distinction between **verified by inspection** and **verified by execution**.
- Status labels: implemented, manual, deferred, rejected, needs live validation.

## File routing
- Policy and frozen state → `PROJECT-STATE.md`
- Front door → `README.md`
- Install, run, test, recovery → `docs/*.md`
- Audit and coverage → `docs/audit/*.md`
- Nix entrypoints → `flake.nix`, `hosts/nixos/default.nix`, `profiles/*.nix`
- Security modules → `modules/security/*.nix`
- Desktop modules → `modules/desktop/*.nix`
- Home Manager → `modules/home/*.nix`

## Working method
1. Read `PROJECT-STATE.md`.
2. Find the smallest authoritative code surface.
3. Make the change.
4. Update `PROJECT-STATE.md` and the ledger if status changed.
5. Update audit steps if the change creates new failure modes.

## Review checklist
- Did code change behavior? → update `PROJECT-STATE.md`
- Did topic coverage change? → update `docs/audit/SOURCE-TOPIC-LEDGER.md`
- Did manual steps change? → update `docs/POST-STABILITY.md` and `docs/TEST-PLAN.md`
- Did failure modes change? → update `docs/PRE-INSTALL.md`

## Defaults Policy (options.nix)
**Principle**: Maximize hardening without user pain.

**Rule**: `options.nix` defaults must balance:
1. **Transparent hardening** enabled (initOnAlloc, slabNomerge, root lock, PTI)
2. **Painful hardening** disabled or permissive (ptrace=1 for games, apparmor off, sandbox.browsers and sandbox.vms off)
3. **Escalation path** clear via profile opt-in (paranoid hardens everything with mkForce)

**Rationale**: Default user didn't choose pain. Paranoid user did.
