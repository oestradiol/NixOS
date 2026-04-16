# Technical debt inventory

Snapshot of everything in the repo that is **temporary**, **pending**, **commented-out**,
**staged off**, or **explicitly deferred**. Generated 2026-04-16 from an exhaustive
sweep of all `.nix`, `.md`, and `.sh` files; last refreshed 2026-04-16 after the
A1–A7 / D1–D2 operator decisions landed.

Scope policy:
- This file tracks debt that lives INSIDE the repo (code comments, disabled blocks,
  scaffolding, workaround notes). Policy-level "staged" features already tracked in
  `docs/maps/HARDENING-TRACKER.md` are cross-referenced here, not duplicated.
- Live-system state issues (failed units, full tmpfs, dangling symlinks) that are
  cleared by a rebuild+reboot are captured under *Operational follow-ups*.
- Operator-local artefacts (gitignored: `hosts/nixos/local.nix`, `LOCAL-NOTES.md`,
  `switch.log`) are explicitly out of scope for publication; they are mentioned only
  when they relate to a debt item here.

## 1. Commented-out code in active modules

All rows carry an explicit operator decision. `kept (deferred)` means the block is
deliberately preserved with a WHY; `kept (documented)` means the comment is a recipe,
not debt. Anything whose row used to say `decide` has been resolved and either landed
in code or been deleted since the last refresh.

| path | lines | what | decision |
|---|---|---|---|
| `modules/core/boot.nix` | 9-20 | `boot.loader.systemd-boot.extraInstallCommands` (daily default-entry picker) | **known bug**; kept commented until Lanzaboote graduates. Tracked in `POST-STABILITY.md` §9; regression covered by `tests/bugs/010-systemd-boot-extrainstall.sh`. |
| `modules/desktop/base.nix` | 17-23 | `# services.dbus.implementation = "broker";` | **A1 — kept (deferred)**: dbus-broker caused a boot-time hang on a D-Bus message on target hardware 2026-04. In-code comment now records the reason. Do NOT re-enable without validating greetd/regreet, plasma6, xdg-portal, pipewire, and bwrap wrappers under dbus-broker. |
| `modules/security/secrets.nix` | 11-12 | example `age.secrets.mullvad-account` + `age.secrets.ssh-private` placeholders | **A3 — kept (deferred)**: scaffolding retained while secrets are not yet populated. Drop once the secret layout is finalised AND the self-owned WireGuard path graduates. |
| `modules/security/sandboxed-apps.nix` | 95-113 | `safeVrcxDaily`, `safeWindsurfDaily`, `safeVrcxDesktop`, `safeWindsurfDesktop` commented in `systemPackages` | **A4 — kept (deferred)**: wrapper let-bindings are the shipping implementation and MUST NOT be deleted. VRCX + Windsurf currently ship as plain packages via home-manager. Swap to the bwrap-wrapped form once the Steam/gamescope chain is stable and the portal/file-chooser passthrough has been validated. |
| `modules/desktop/gaming.nix` | 64-65 | `# mangohud`, `# protontricks` in `systemPackages` | **A6 — kept (deferred)**: enable on demand; neither is needed for the current baseline. `protonup-qt` (sibling line) is **enabled** and manages Proton builds at runtime. |
| `modules/security/privacy.nix` | 38-39 | hostname-randomization one-liner in a comment | **kept (documented)**: deliberately disabled because it breaks local network identification. The comment is a runtime recipe, not debt. Do not promote to an option unless requested. |

Resolved since last refresh (no longer rows here):
- **A2**: commented PAM-hook blocks + unreachable `profileCheckScript` let-binding in `modules/security/user-profile-binding.nix` — **deleted**. File reduced to its guardrail assertion; see §4.
- **A5**: `#proton-ge-bin` in `modules/desktop/gaming.nix` — **deleted**. `protonup-qt` enabled in its place; Proton variants are now a runtime choice, not a rebuild.

## 2. Temporary fixes / workaround notes

Comments that explicitly mark non-permanent design.

| path | lines | note | status |
|---|---|---|---|
| `modules/core/boot.nix` | 26-33 | Lanzaboote `extraInstallCommands` incompatibility workaround: `loader.settings.default = "@saved"` | **baseline**; the note documents a valid upstream gap, no action required |
| `hosts/nixos/fs-layout.nix` | 10 | LUKS `allowDiscards` disabled (`periodic fstrim` instead) | **baseline**, deliberate trade-off documented |

Resolved since last refresh:
- **A7**: the `Temp fix: auto-mount external drive` block previously at the bottom of `hosts/nixos/fs-layout.nix` has been **moved out of the tracked tree** into `hosts/nixos/local.nix` (gitignored). `hosts/nixos/default.nix` now imports it via `lib.optional (builtins.pathExists ./local.nix)` so the entry is a no-op on any machine that does not host the external drive. See `README.md` → "Operator-local overrides".

## 3. Staged features (off by default in both profiles)

These are tracked first-class in `docs/maps/HARDENING-TRACKER.md`. Enumerated here for
completeness so "what can we turn on next?" has a single answer.

| knob | file | graduation signal |
|---|---|---|
| `myOS.security.secureBoot.enable` | `modules/security/secure-boot.nix` | first clean encrypted-boot validation + recovery drill |
| `myOS.security.tpm.enable` | `modules/security/secure-boot.nix` | same as Secure Boot |
| `myOS.security.wireguardMullvad.enable` | `modules/security/wireguard.nix` | secrets populated, endpoint/pubkey validated |
| `myOS.security.hardenedMemory.enable` | `modules/security/base.nix:145-147` | Plasma 6 + NVIDIA stability validated with graphene allocator |
| `myOS.security.auditRules.enable` | `modules/security/base.nix:33-69` | upstream nixpkgs AppArmor↔audit-rules compatibility resolved |
| `myOS.security.kernelHardening.oopsPanic` | `modules/core/boot.nix` | validated on target hardware (availability-risk) |
| `myOS.security.kernelHardening.moduleSigEnforce` | `modules/core/boot.nix` | validated on target hardware (driver friction) |
| `myOS.security.kernelHardening.modulesDisabled` | `modules/security/base.nix:105-108` | everything needed is proven loaded at boot |
| `users.mutableUsers = false` | `modules/core/users.nix` | declarative secret-backed passwords deployed |

## 4. Rejected but still in-tree

Code exists but governance already classified it as "do not add".

| path | status |
|---|---|
| `modules/security/user-profile-binding.nix` | **rejected** per HARDENING-TRACKER; file reduced to a guardrail assertion that fires if `myOS.security.pamProfileBinding.enable` is ever flipped on. Keep — removing the file would let someone re-enable the option without tripping the guardrail. |
| `profiles/*` + references to `hidepid` / `unprivileged_userns_clone=0` | **absent**/**rejected**; no code, no action |

## 5. Operational follow-ups (live-system state)

These are not code debt — they will clear with a rebuild+reboot after the 2026-04 fix
set lands. Listed so nothing is lost.

| symptom | surfaced by | root cause | clears when |
|---|---|---|---|
| `/` tmpfs at 100% | `tests/runtime/010-system-health.sh` | 4G tmpfs too small for KDE + VR + IDE | Fix 3 lands + reboot releases deleted-but-held inodes |
| `~player/.nix-profile` dangling | `tests/runtime/180-shell-env.sh` | HM activation hit tmpfs-full during last switch | Fix 3 + one successful rebuild |
| `logrotate.service` failed | `tests/runtime/010-system-health.sh` | `/var/lib/logrotate.status.tmp` on tmpfs root | Fix 4 (persist `/var/lib/logrotate`) + rebuild |
| `fwupd.service` failed | `tests/runtime/010-system-health.sh` | `/var/lib/fwupd` write hit tmpfs-full | Fix 3 + Fix 4 (persist `/var/lib/fwupd`) + rebuild |
| `fwupd-refresh.service` failed | dependency of fwupd | same as above | same |
| `clamav-impermanence-scan.service` / `clamav-deep-scan.service` failed (2/INVALIDARGUMENT) | `tests/runtime/010-system-health.sh` | `/var/lib/clamav` empty: freshclam hasn't populated the CVD DB AND that dir is on tmpfs | Fix 4 extension (persist `/var/lib/clamav`) + first run of `clamav-freshclam.service` post-rebuild |
| `avahi-daemon.service` active + `avahi` user present | `tests/runtime/220-misc-services.sh` | upstream wivrn.nix forced avahi; no override before Fix 2 | Fix 2 lands + rebuild |
| `switch.log` records `profile-mount-invariants` failure | `tests/bugs/020-profile-mount-switch.sh` (warn) | historical artefact of the pre-fix alias | **cleared 2026-04-16**: `switch.log` deleted; now gitignored. `bugs/020` + `bugs/030` treat absence as PASS. |
| `/etc/ssh/ssh_host_*_key{,.pub}` dangling symlinks | `tests/runtime/200-persistence.sh` | pre-fix impermanence.nix persisted those paths unconditionally; sshd is disabled so no keys exist in `/persist/etc/ssh/` | fix landed in `modules/security/impermanence.nix` (now gated on `config.services.openssh.enable`); clears on first rebuild |

## 6. Non-obvious repo conventions worth keeping documented

These are not debt, but explain comment patterns a reviewer might otherwise flag.

- All `lib.mkForce` usages in `profiles/daily.nix` are **intentional** — daily
  explicitly overrides the hardened base. Not debt.
- `networking.firewall.interfaces.<iface>.allowedUDPPorts = [ 9 ]` is the WoL-over-UDP
  compatibility rule; the L2 magic packet path needs nothing. See
  `modules/security/networking.nix:16-29`.
- `services.avahi.enable = lib.mkForce false` in `modules/desktop/vr.nix` is required
  because upstream `services/video/wivrn.nix` sets it without `mkDefault`. Do not
  "simplify" to `mkDefault`.
- `services.geoclue2.enable = lib.mkForce false` in `modules/desktop/base.nix` is
  required because Plasma 6 enables it via `mkDefault`. Same deal.
- `hosts/nixos/default.nix` imports `hosts/nixos/local.nix` only via
  `lib.optional (builtins.pathExists ./local.nix)` — the file is gitignored and
  absence is a no-op; this is the sanctioned extension point for per-install
  hardware quirks, never for policy.
- `--show-trace` on every `flake-*` rebuild alias is the debug-phase posture; drop
  once the first fully-clean rebuild lands (operator decision C1). Tracked in
  `HARDENING-TRACKER.md` "Operator ergonomics / rebuild".

## Conventions

- Categories above are exhaustive. If you're adding new debt to the repo, add a row
  here FIRST, then let the static layer catch you.
- Row statuses follow the HARDENING-TRACKER state machine: `baseline`, `staged`,
  `known bug`, `rejected`.
- Decision phrasing inside §1:
  - `kept (deferred)` — block deliberately preserved with an explicit WHY and a
    condition under which it would be re-evaluated.
  - `kept (documented)` — in-code recipe / reference, not debt.
  - `decide` — open item pending operator sign-off. Should be rare and transient.
- When a decision lands, move the row out of the table and into the adjacent
  "Resolved since last refresh" list so the history isn't lost.
