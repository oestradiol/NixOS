# AUDITS

Canonical audit surface: what has been checked, what is only statically verified, what still needs runtime proof, and what is intentionally deferred.

## Audit status summary
- repo structure and file-role pass: complete
- governance/navigation pass: complete
- explicit policy propagation pass across top-level truth surfaces: complete
- docs truth-surface alignment pass: complete
- sandbox-core correctness pass: complete
- browser split correction pass: complete
- machine-id policy correction pass: complete
- staged WireGuard documentation pass: complete
- helper-script responsibility pass: complete
- current-stage pipeline pass: complete
- runtime validation on target hardware: not complete

## Validation ledger
| surface | state | validation mode | canonical locations | notes |
|---|---|---|---|---|
| shared sandbox core | implemented | static review | `modules/security/sandbox-core.nix`, `modules/security/browser.nix`, `modules/security/sandboxed-apps.nix` | shared constructor, explicit relaxations, cleared environment |
| daily Firefox enterprise-policy path | implemented | static review | `modules/security/browser.nix`, `docs/governance/PROJECT-STATE.md`, `docs/pipeline/TEST-PLAN.md` | normal Firefox path, not arkenfox-managed |
| paranoid `safe-firefox` arkenfox-derived baseline | implemented | static review | `modules/security/browser.nix`, `modules/security/arkenfox/user.js`, `docs/governance/PROJECT-STATE.md`, `docs/pipeline/TEST-PLAN.md` | wrapper + vendored arkenfox + repo overrides |
| Tor Browser / Mullvad Browser wrapper path | implemented+manual | static review | `modules/security/browser.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/POST-STABILITY.md` | upstream browser model kept; wrapper compatibility still needs runtime trials |
| daily app wrappers (e.g., safe-Electron-app) | implemented+manual | static review | `modules/security/sandboxed-apps.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/RECOVERY.md` | functionality must be proven on target desktop; template-specific apps configured in templates/ |
| staged self-owned WireGuard path | implemented | static review | `modules/security/wireguard.nix`, `modules/security/networking.nix`, `docs/pipeline/INSTALL-GUIDE.md`, `docs/pipeline/TEST-PLAN.md` | present in repo, off by default |
| paranoid audit subsystem | implemented | static review | `modules/security/base.nix`, `profiles/paranoid.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/RECOVERY.md` | `security.audit` + `auditd` are baseline on paranoid |
| repo custom audit rules | deferred | static review | `modules/security/base.nix`, `modules/core/options.nix`, `docs/pipeline/POST-STABILITY.md`, `docs/pipeline/TEST-PLAN.md` | intentionally defaulted off pending upstream fix and live revalidation |
| AppArmor framework baseline | implemented+manual | static review | `modules/security/base.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/POST-STABILITY.md` | framework + D-Bus mediation only; no custom profile library yet |
| ClamAV + AIDE monitoring path | implemented | static review | `modules/security/scanners.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/RECOVERY.md` | timers/services still need live validation |
| Flatpak + Flathub + portals | implemented | static review | `modules/security/flatpak.nix`, `docs/pipeline/TEST-PLAN.md`, `docs/governance/PROJECT-STATE.md` | containment for relatively trusted GUI apps, not hostile-software guarantee |
| VM tooling layer + workflow classes | implemented | static review | `modules/security/vm-tooling.nix`, `docs/governance/PROJECT-STATE.md`, `docs/pipeline/TEST-PLAN.md`, `docs/pipeline/POST-STABILITY.md` | host-side automation present; guest templates still need runtime proof |
| profile-user binding | implemented | static review | `modules/core/users.nix`, `modules/security/user-profile-binding.nix` | enforced via account locking; PAM approach remains disabled |

## Claim ledger
- daily Firefox is configured through Firefox enterprise policies, not through the vendored arkenfox file
- paranoid Firefox uses the vendored arkenfox baseline plus repo overrides inside the sandboxed wrapper
- Tor Browser and Mullvad Browser are not rewritten into arkenfox-managed browsers; they keep their upstream privacy model and only receive local wrapper containment from this repo
- the paranoid audit baseline means the Linux audit subsystem and `auditd`; repo custom audit rules are a separate staged surface and are currently off by default
- Flatpak is treated here as a containment layer for relatively trusted GUI apps, not as the sandbox for hostile software
- same-kernel wrappers are not described here as VM-equivalent isolation

Reference set index: `REFERENCES.md`

## Runtime backlog
Still needs target-machine validation:
- daily first boot and recovery path
- paranoid `safe-firefox` runtime validation
- Tor Browser wrapper runtime matrix
- Mullvad Browser wrapper runtime matrix
- Electron app wrapper launch/file-chooser validation (template-specific apps)
- live VM class validation and guest-template refinement
- scanner timers/services and AIDE initialization flow

## Governance rules for future passes
- static review is not runtime proof
- staged features must not be described as baseline
- rejected surfaces must stay clearly rejected until reworked
- every implemented surface must live in exactly one of these states: baseline, staged, deferred, or rejected-for-baseline
- every document should describe only its own role and point elsewhere for the rest
