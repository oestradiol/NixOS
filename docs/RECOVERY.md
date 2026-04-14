# RECOVERY

Overall map of failure modes. Prefer rollback and minimal targeted fixes.

## 1. System does not boot
- boot an older generation if available
- otherwise boot external recovery media
- mount the encrypted root and `/persist`
- inspect the last attempted generation and revert the breaking change

## 2. Daily boots but paranoid does not
- boot daily
- rebuild paranoid only after reading the failure cause
- compare `profiles/paranoid.nix`, `modules/security/wireguard.nix`, `modules/security/browser.nix`, and `modules/security/vm-tooling.nix`

## 3. Secure Boot broke boot
- disable Secure Boot in firmware temporarily
- boot the last known-good generation
- inspect enrollment state and key paths
- do not keep changing both boot policy and unrelated settings in the same recovery pass

## 4. TPM unlock broke boot
- use the recovery passphrase
- boot the known-good generation
- inspect TPM enrollment state and PCR binding assumptions

## 5. `/persist` did not mount
Symptoms:
- machine-id changed unexpectedly
- SSH host keys changed
- user state missing

Recovery:
- mount the root volume and `/persist`
- verify the filesystem entries in the generated config
- confirm the expected persisted directories still exist
- rebuild only after `/persist` is visible again

## 6. Machine-id drift or override confusion
Expected state now:
- both profiles keep a unique persisted host machine-id
- paranoid no longer uses the Whonix shared ID

Recovery:
- inspect `/etc/machine-id`
- inspect `modules/security/impermanence.nix`
- inspect `profiles/paranoid.nix`
- remove any accidental explicit override unless intentionally documented

## 8. Paranoid audit or AppArmor fails

If `audit-rules-nixos.service` fails, `auditctl -l` shows no repo rules, or `aa-status` reports AppArmor is inactive:
- compare `modules/security/base.nix`, `profiles/paranoid.nix`, and `PROJECT-STATE.md`
- inspect `systemctl status audit-rules-nixos.service auditd` and `journalctl -u audit-rules-nixos.service -u auditd -b`
- inspect `dmesg | grep -i apparmor` and `aa-status`
- if AppArmor is active but the audit-rule loader fails on the target nixpkgs revision, keep the rule set documented and move the exact breakage into `docs/POST-STABILITY.md` with logs
- if a custom future AppArmor policy causes breakage, revert that policy first before weakening the framework baseline

## 7. Staged self-owned WireGuard does not connect
Use this only if you explicitly enabled the staged self-owned WireGuard path. Check these first:
- private key path exists
- server public key is correct
- address is correct
- endpoint is literal `IP:port`
- nftables rules built successfully

If the endpoint IP changed at the provider:
1. resolve the relay hostname from a trusted environment
2. update the pinned IP in the paranoid config
3. rebuild and reconnect

## 8. Paranoid network blocks too much
- confirm the tunnel interface exists
- confirm the endpoint IP and port are correct
- inspect nftables for the exact non-WG exception
- confirm DNS is only allowed through the tunnel
- do not widen the rule to a hostname-based DNS exception unless intentionally changing policy

## 9. Browser wrapper fails to launch
Likely causes:
- display socket missing
- GPU device mismatch
- package-specific startup quirk
- portal or D-Bus need not yet modeled

Recovery flow:
1. isolate whether the break is wrapper-specific
2. inspect display variables and runtime socket presence
3. inspect whether the wrapper needs an additional explicit portal or D-Bus allow entry
4. document the exact minimum relaxation before changing code

## 10. `safe-vrcx` or `safe-windsurf` fails
Likely causes:
- missing portal permission
- GPU/device requirement
- package expects a path outside the current persistence allowlist

Recovery flow:
1. verify the host app runs outside the wrapper
2. compare persisted paths in `modules/security/sandboxed-apps.nix`
3. add only the exact missing path or bus name
4. update `TEST-PLAN.md` and `POST-STABILITY.md`

## 11. Portal or file chooser breaks
- confirm `sandbox.dbusFilter = true` is set as expected
- verify portal services are actually available on the host session
- add only the missing portal talk/broadcast permission if necessary
- avoid broad session-bus exposure as a quick fix

## 12. GPU breakage inside wrappers
- confirm whether the app actually needs GPU access
- verify the relevant `/dev/dri` or NVIDIA device nodes exist
- if the app does not need GPU, keep GPU disabled
- if it does, expose only the exact nodes already modeled in the core

## 13. VM tooling exists but the wrong class is being used
This is a workflow/policy failure, not just a code failure.
Before changing host code, identify the intended class:
- `trusted-work-vm` for lower-risk compartmentalized work
- `risky-browser-vm` for risky web use
- `malware-research-vm` for hostile binaries or malware-adjacent work
- `throwaway-untrusted-file-vm` for unknown documents or archives
Then compare the class policy in `PROJECT-STATE.md` across all six layers:
- threat class
- host-to-guest boundary
- network
- disposability
- guest baseline
- operator workflow
If the class policy itself proves insufficient on the real machine, document that gap in `docs/POST-STABILITY.md` before widening host defaults.

## 14. Performance regression
- compare against a last known-good build
- isolate whether the regression is kernel hardening, wrapper changes, GPU changes, or VPN path changes
- revert one class of change at a time

## 15. Secrets unavailable
If age or WireGuard secret files are missing:
- restore them from secure backup
- verify file paths referenced in config
- rebuild only after the secret files exist again

## 16. Last-resort rollback rule
When multiple things break at once:
- roll back to the last known-good generation
- restore one security change at a time
- do not combine unrelated relaxations in one recovery step

## VM class reality check
- if host-side VM automation works but a class still behaves badly, assume guest templates and real-world tuning still need live trials
- do not widen host defaults first; compare the class against `PROJECT-STATE.md`, `docs/TEST-PLAN.md`, and `docs/POST-STABILITY.md` before relaxing the host policy
