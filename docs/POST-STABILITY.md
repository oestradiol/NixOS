# POST-STABILITY

More aggressive decisions, refactors, trials, and everything deferred for the current stage.

## 1. Shared sandbox core follow-up
- add seccomp support to the shared sandbox core
- evaluate Landlock support in the shared sandbox core
- derive per-app syscall policy instead of guessing

## 2. Daily wrapper follow-up
If `safe-vrcx` or `safe-windsurf` breaks:
- debug only the exact missing path, portal permission, or bus name
- keep broad home, broad `/var`, and broad `/run/user/$UID` exposure rejected
- update `RECOVERY.md` and `TEST-PLAN.md` with the minimum proven relaxation only

## Daily post-stability track
- once daily is operable, use post-stability to tighten daily only where the real desktop baseline proves it can tolerate more
- prefer low-breakage wins first: proven browser-relaxation reductions, wrapper tightening, service hardening that does not destabilize gaming/VR/socialization, and better monitoring
- do not let daily post-stability work block the initial goal of getting to a recoverable daily desktop quickly

## 3. Browser follow-up
- test Firefox, Tor Browser, and Mullvad Browser on the target hardware
- keep `safe-firefox` on the stricter local Firefox baseline unless a specific paranoid constraint forces a relaxation
- Tor Browser and Mullvad Browser can be fragile under aggressive containment; treat them as a careful tightening program, not a one-shot hardening pass
- document which wrapper relaxations are strictly necessary versus which ones are only convenience
- test whether GPU can be removed for any browser without unacceptable breakage
- add stricter no-GPU browser variants if they prove useful

## 4. WireGuard maintenance and monitoring
Paranoid uses a pinned endpoint IP.
This is the best current option for the repo because it avoids a standing hostname/DNS leak path in the paranoid firewall model.
What remains manual:
- monitor whether the provider rotated the relay IP
- repin the endpoint when needed from a trusted environment
- re-run the paranoid network checks in `TEST-PLAN.md`
- evaluate a `systemd.network` migration only if live validation shows routing, MTU, DNS, or interface-ordering issues that the current `networking.wireguard` design does not handle cleanly
Do not move this earlier in the pipeline than post-stability operation, because the install-stage task is only to provide the initial pinned endpoint.

## 5. VM workflow follow-up
The four VM classes and six-layer policy are now encoded in `PROJECT-STATE.md` and host-side automation exists through repo-managed networks plus `repo-vm-class`.
What remains deferred here is deeper validation and tightening, not basic class automation.
Still do later:
- build or select class-specific guest templates instead of relying on operator-supplied base images alone
- add stronger reset and snapshot automation where real usage shows it helps
- validate each class on the real machine and tighten defaults based on lived breakage
- guest templates and real-world tuning still need live trials before any class is treated as fully proven
- only after daily is operable and paranoid reaches minimum functional state, use post-stability to push paranoid toward the maximum achievable hardening under the repo constraints
Do not describe VM support as magic isolation; it is class-aware host automation plus guest policy that still needs real-world validation.

## 6. Secure Boot and TPM rollout
Do this only after both profiles boot reliably.
Then document the exact enrollment and rollback steps that worked on the real machine.

## 7. Machine-id note
The shared Whonix machine-id design was removed.
Do not reintroduce it casually.
If you ever want to revisit that idea, keep it as a documented experiment here first and do not treat it as baseline policy.

## Audit and AppArmor follow-up
### Why AppArmor is not “finished” yet
- framework enablement is not the same as broad policy coverage
- reboot semantics matter when first enabling the framework
- profile rollout needs explicit complain/enforce handling and denial-log review
- `killUnconfinedConfinables` can change process behavior when new policies appear, so it remains post-stability only

- consider `security.audit.enable = "lock"` only after build-vm or spare-boot validation
- if `audit-rules-nixos.service` misbehaves on the target nixpkgs revision, keep the repo rule set but document the exact failure and re-test after upstream fixes
- custom AppArmor policy rollout is deferred: first confirm the framework and D-Bus mediation baseline are stable, then add repo-maintained policies incrementally
- evaluate `security.apparmor.killUnconfinedConfinables` only after a spare-boot or disposable validation path exists, because it can kill newly confinable processes when policy coverage changes
- decide whether any repo-maintained profiles should begin in complain mode before enforce mode, then record the exact promotion criteria
- add a small profile-validation workflow: check loaded profiles, denial logs, complain/enforce state, and any D-Bus mediation regressions after each policy addition
- do not import third-party AppArmor policy bundles blindly; NixOS path layout and current upstream packaging still need careful validation

## Paranoid browser live trials
- Tor Browser and Mullvad Browser can be fragile under aggressive local containment
- push containment tighter only after each target GPU/session/portal combination is proven functional
- trial matrix should expand in this order: runtime sockets, portals, GPU exposure, D-Bus allowances, then any stricter browser-specific toggles

## PAM profile-binding
- keep `myOS.security.pamProfileBinding.enable` off for the current stage
- only trial it after a full lockout-recovery rehearsal and console recovery path check
- if enabled later, add dedicated login, sudo, su, and display-manager tests before treating it as baseline

## 10. Stronger governance beyond `.nix` validation
- defer stronger governance that audits docs for drift, consistency, losslessness, and file-purpose boundaries
- use the stronger governance pattern from the Aistra / Research repos as the model: authoritative surface registry, claim-expectation registry, file-justification registry, repository file registry, and integrity/launch gates
- keep current repo governance truthful and lighter for this stage; do not block installation or first validation on those stronger checks
- once daily and paranoid are both stable, add a doc-governance layer that can fail CI or local audit when code/docs/pipeline drift

## Reference governance and archiving
- `REFERENCES.md` is now the canonical source ledger
- archive capture is still incomplete; move high-tier sources into an immutable archived set later
- add exact section/header pinning and freshness dates for the most load-bearing claims
- once stronger governance is implemented, make reference drift visible alongside code/doc drift
