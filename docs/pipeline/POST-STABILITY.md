# POST-STABILITY

Only work that happens after the first stable machine-usable baseline is already complete.

## Rule
Do not move anything from this file into the baseline path unless it is revalidated and then promoted into `docs/pipeline/TEST-PLAN.md`.

## 1. Secure Boot and TPM rollout
After the encrypted baseline is stable:
- enable the staged Secure Boot path
- enroll keys with `scripts/post-install-secureboot-tpm.sh`
- validate boot and recovery
- then stage TPM-bound unlock only after Secure Boot is already understood and recoverable

## 2. Repo custom audit rules
Current state:
- paranoid baseline keeps the Linux audit subsystem and `auditd`
- repo custom audit rules remain off by default

Post-stability work:
- retest the upstream nixpkgs issue on your pinned revision
- enable `myOS.security.auditRules.enable` only after the issue is fixed and proven on your machine
- promote the rule set into baseline only after a clean real-machine validation pass

## 3. Custom AppArmor policy library
Current state:
- framework and mediation baseline only
- no repo-maintained custom profile library in baseline

Post-stability work:
- add policies incrementally
- test complain/enforce state explicitly
- do not call the library baseline-ready until login, browser launch, and core desktop flows are clean

## 4. Browser tightening beyond minimum functionality
Current baseline already gives:
- daily Firefox policy management
- paranoid `safe-firefox` with arkenfox + wrapper containment
- Tor Browser / Mullvad Browser wrappers

Post-stability work:
- GPU/no-GPU browser matrix
- stricter D-Bus and portal trials
- Tor Browser wrapper compatibility matrix
- Mullvad Browser wrapper compatibility matrix
- any tighter `/etc` reductions beyond the current minimal allowlist

## 5. VM guest-template refinement
Current baseline already gives host-side VM class tooling.
Still deferred:
- guest image selection and template polish
- guest-hardening baselines per class
- convenient import/export workflow refinement
- rollback/snapshot habits that are proven in real use

## 6. Stronger governance and drift checking
Current baseline governance is intentionally light.
Post-stability work can add:
- stronger doc/code drift gates
- stricter file-role enforcement
- richer reference freshness tracking
- launch/audit gates inspired by the stronger governance pattern you already use elsewhere

## 7. Lanzaboote feature parity tracking
Current state:
- systemd-boot used by default with extraInstallCommands for default daily entry
- Secure Boot path uses Lanzaboote with `settings.default = "@saved"` to preserve last-selected entry
- Lanzaboote does not support boot.loader.systemd-boot.extraInstallCommands
- Lanzaboote removes specialization names from boot entries (cannot distinguish daily vs paranoid in boot menu)
- Workaround: @saved preserves user's last boot selection as reasonable compromise

Track upstream issues:
- https://github.com/nix-community/lanzaboote/issues/375 - Extending bootloader installation (extraInstallCommands support)
- https://github.com/nix-community/lanzaboote/issues/393 - Setting specialisation as default boot entry
- https://github.com/nix-community/lanzaboote/issues/394 - Specialisations not identifiable in boot menu
- https://github.com/nix-community/lanzaboote/issues/94 - Feature parity with systemd-stub

Post-stability work:
- Monitor for extraInstallCommands support in Lanzaboote
- Monitor for specialization naming fix in boot entries
- Test Lanzaboote's default boot entry behavior when specialization identification is fixed
- Consider switching to Lanzaboote as default if feature parity is achieved
