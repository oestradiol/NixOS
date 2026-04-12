# NixOS Hardening Workspace

One host, two boot specialisations: **daily** (gaming/VR/desktop) and **paranoid** (hardened workstation). Users: `player` / `ghost`. tmpfs root + impermanence. Secure Boot + TPM staged after first boot.

Public-safe: no real secrets, `secrets/` is scaffolding only.

## Scope

- 20+ hardened sysctls, kernel module blacklist, coredump off, root locked, su wheel-only
- zram (zstd 50%) + 8GB Btrfs swap file on `@swap` subvolume
- tmpfs root + impermanence with explicit `/persist` model
- Defense-in-depth nftables killswitch with DHCP/DNS exceptions; USB restricted on paranoid
- Browser policy split: FPP-hardened Firefox (daily) vs sandboxed UID-isolated wrappers (paranoid)
- Systemd service hardening for flatpak-repo, ClamAV (daily shallow + weekly deep), AIDE with weekly timers
- Agenix secrets scaffold, Secure Boot + TPM staged after first boot
- 27 governance assertions catch config drift at build time
- All hardening knobs configurable via `myOS.security.*` options per-profile

## Repository layout

```
flake.nix                       # entrypoint
hosts/nixos/                    # host config, hardware, disk layout
profiles/                       # daily.nix, paranoid.nix
modules/
  core/                         # boot, desktop (locale+audio+nix), options, users
  security/                     # hardening, networking, browser (sandboxed),
                                # impermanence, secure-boot (+ TPM), flatpak,
                                # scanners, secrets, governance, vm-isolation
  desktop/                      # gaming (steam, gamescope, controllers knob), vr,
                                # theme, shell
  home/                         # HM modules: common, player, ghost
  gpu/                          # nvidia, amd
scripts/                        # install, post-install, audit helpers
docs/                           # see below
```

## Docs

| File | Purpose |
|---|---|
| `PROJECT-STATE.md` | Frozen decisions, implemented/deferred/rejected items, trust model, user decisions |
| `docs/INSTALL-GUIDE.md` | Destructive install + persistence map |
| `docs/POST-STABILITY.md` | Post-stability steps, manual follow-ups, monitoring notes, deferred items |
| `docs/TEST-PLAN.md` | Runtime verification checklist |
| `docs/PRE-INSTALL.md` | Pre-install checks, code map, failure modes |
| `docs/RECOVERY.md` | Emergency recovery procedures |
| `docs/PERFORMANCE-NOTES.md` | Old vs new daily comparison, per-knob impact, decision rules |
| `docs/audit/SOURCE-TOPIC-LEDGER.md` | Canonical hardening topic tracker |
| `docs/audit/SOURCE-COVERAGE-MATRIX.md` | 18 external sources reviewed with audit provenance |

## Audit order

1. `PROJECT-STATE.md` — current state, decisions, trust model
2. `docs/audit/SOURCE-TOPIC-LEDGER.md` — topic coverage
3. `docs/PRE-INSTALL.md` → `docs/INSTALL-GUIDE.md` → `docs/TEST-PLAN.md` → `docs/POST-STABILITY.md`
4. `docs/RECOVERY.md` — emergency recovery procedures
5. Code: `profiles/` → `modules/security/` → `modules/security/governance.nix`

## Rules

1. Never commit real credentials, age files, or private keys.
2. Treat all security claims as untrusted until verified by live boot.
3. If code changes behavior, update `PROJECT-STATE.md` in the same commit.
4. Tool agents: start with `AGENTS.md` then `PROJECT-STATE.md`.
