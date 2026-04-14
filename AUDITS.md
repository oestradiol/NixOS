# AUDITS

Canonical audit surface: completed checks, source-backed claim ledger, validation status, and remaining audit backlog.

## Audit status summary
- static repo architecture pass: complete
- canonical reference-ledger pass: complete
- docs boundary/compression pass: complete
- shared sandbox-core refactor pass: complete
- machine-id policy correction pass: complete
- paranoid WireGuard pinned-endpoint pass: complete
- script responsibility/flow validation pass: complete
- runtime validation on target hardware: not complete
- pipeline coverage closure pass: complete

## Validation ledger
| surface | state | validation mode | canonical locations | notes |
|---|---|---|---|---|
| shared sandbox core | implemented | static review | `modules/security/sandbox-core.nix`, `modules/security/browser.nix`, `modules/security/sandboxed-apps.nix` | one constructor, explicit relaxations |
| daily Firefox arkenfox-derived baseline | implemented | static review | `modules/security/browser.nix`, `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | relaxed only for daily usability |
| paranoid `safe-firefox` arkenfox-derived baseline | implemented | static review | `modules/security/browser.nix`, `PROJECT-STATE.md`, `docs/TEST-PLAN.md` | stricter local baseline inside wrapper |
| Tor Browser / Mullvad Browser wrapper path | implemented+manual | static review | `modules/security/browser.nix`, `docs/POST-STABILITY.md`, `docs/TEST-PLAN.md` | further tightening trials deferred |
| paranoid WireGuard pinned endpoint | implemented | static review | `modules/security/wireguard.nix`, `profiles/paranoid.nix`, `docs/PRE-INSTALL.md`, `docs/TEST-PLAN.md` | exact endpoint exception only |
| paranoid audit path | implemented | static review | `modules/security/base.nix`, `profiles/paranoid.nix`, `docs/TEST-PLAN.md`, `docs/RECOVERY.md` | audit subsystem + auditd + repo rules; live validation still required |
| AppArmor baseline | implemented+manual | static review | `modules/security/base.nix`, `profiles/daily.nix`, `profiles/paranoid.nix`, `docs/TEST-PLAN.md`, `docs/POST-STABILITY.md` | framework + D-Bus mediation baseline; custom repo profiles deferred |
| ClamAV + AIDE monitoring path | implemented | static review | `modules/security/scanners.nix`, `docs/TEST-PLAN.md`, `docs/RECOVERY.md` | live timer/service validation still required |
| Flatpak remote + portal baseline | implemented | static review | `modules/security/flatpak.nix`, `docs/TEST-PLAN.md` | remote bootstrap and portal path are in current-stage validation |
| fwupd baseline | implemented | static review | `modules/desktop/base.nix`, `docs/TEST-PLAN.md` | current-stage runtime check required |
| privacy network-identity settings | implemented | static review | `modules/security/privacy.nix`, `docs/TEST-PLAN.md` | verify MAC and TCP timestamp mode per profile |
| VM tooling layer + workflow classes | implemented | static review | `modules/security/vm-tooling.nix`, `PROJECT-STATE.md`, `docs/TEST-PLAN.md`, `docs/POST-STABILITY.md` | repo-managed NAT + isolated networks and `repo-vm-class` encode the four classes; guest templates still need live validation |
| wrapper seccomp | deferred | static review | `PROJECT-STATE.md`, `docs/POST-STABILITY.md`, `docs/TEST-PLAN.md` | do not overclaim |
| wrapper Landlock | deferred | static review | `PROJECT-STATE.md`, `docs/POST-STABILITY.md`, `docs/TEST-PLAN.md` | do not overclaim |
| install script | implemented | static review | `scripts/install-nvme-rebuild.sh`, `scripts/README.md`, `docs/INSTALL-GUIDE.md` | destructive layout prep only |
| secure-boot staging script | implemented | static review | `scripts/post-install-secureboot-tpm.sh`, `scripts/README.md`, `docs/POST-STABILITY.md` | staging helper, not full automation |
| audit script | implemented | static review | `scripts/audit-tutorial.sh`, `scripts/README.md`, `AUDITS.md` | read-only handoff script |

## Source-backed claim ledger
- arkenfox is treated here as a desktop Firefox hardening baseline that expects local overrides; the repo therefore vendors a snapshot and appends repo-owned overrides instead of claiming an untouched upstream profile.
- arkenfox is not applied to Tor Browser or Mullvad Browser; those browsers keep their upstream privacy model and only receive local wrapper containment from this repo.
- the paranoid audit claim is tied to the actual NixOS audit subsystem (`security.audit.enable`) plus the repo rule set, not only to `auditd` being present.
- the AppArmor claim is limited to the framework baseline and D-Bus mediation baseline; it is not described as a finished custom policy library.
- the pinned-endpoint WireGuard choice is kept because it removes the standing DNS exception and fits the current nftables design, while the repo still notes that live routing and MTU validation remain necessary.
- the daily/paranoid split is threat-model-driven rather than copy-pasted maximalism; every compromise is expected to stay explicit in code and docs.

Reference set index: `REFERENCES.md`

## Audit backlog
Still needs live or future audit work:
- daily Firefox runtime validation against real sites/workflows
- paranoid `safe-firefox` runtime validation on target hardware
- Tor Browser wrapper regression/failure matrix
- Mullvad Browser wrapper regression/failure matrix
- live paranoid WireGuard killswitch validation
- VM class live validation and template refinement
- stronger doc-governance enforcement layer design
- future seccomp policy design audit
- future Landlock policy design audit

## Governance-relevant audit rules
- static review is not runtime proof
- same-kernel wrappers must not be described as VM-equivalent isolation
- unfinished work must be marked implemented+manual, deferred, or rejected
- if a source warns against blind reuse in another browser, the repo must respect that boundary
- file-purpose discipline and doc drift checks are required eventually, but stronger automated doc-governance is intentionally deferred to post-stability

## Pipeline coverage closure
Every implemented security surface must now land in one of three places:
- current-stage validation in `docs/TEST-PLAN.md`
- explicit defer in `docs/POST-STABILITY.md`
- explicit rejection or support-boundary statement in `PROJECT-STATE.md`

Covered now: audit path, AppArmor baseline, ClamAV, AIDE, fwupd, Flatpak remote/portals, daily Mullvad/resolved path, privacy network-identity settings, and the experimental PAM profile-binding surface.
