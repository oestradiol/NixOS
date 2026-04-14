# TEST PLAN

Exactly everything required to prove the daily profile works first and the paranoid profile reaches its current minimum functional state after daily is already operable.

## 1. Stage order
- [ ] get daily operable first
- [ ] do not spend time chasing paranoid-specific breakage until daily is usable for recovery and iteration
- [ ] only after daily passes sections 2 through 4 should paranoid sections become blocking

## 2. Build and boot
- [ ] `nix flake check` passes
- [ ] daily builds
- [ ] daily boots
- [ ] paranoid builds
- [ ] paranoid boots

## 3. Persistence and identity
- [ ] `/persist` is mounted
- [ ] `/etc/machine-id` is persisted
- [ ] daily machine-id is unique and stable across reboot
- [ ] paranoid machine-id is unique and stable across reboot
- [ ] no profile uses the removed Whonix shared machine-id

## 4. Daily profile
- [ ] Steam works
- [ ] VR path works
- [ ] controllers work
- [ ] Firefox launches normally
- [ ] `about:policies` and the generated Firefox profile match the vendored arkenfox baseline plus repo daily relaxations
- [ ] Mullvad app mode connects and stays usable for ordinary browsing
- [ ] `services.resolved` is active in daily and DNS resolution works normally
- [ ] Flathub remote exists and Flatpak portals work
- [ ] `fwupdmgr get-devices` works
- [ ] `safe-vrcx` launches
- [ ] `safe-windsurf` launches
- [ ] VRCX file chooser works through portals if needed
- [ ] Windsurf file chooser works through portals if needed
- [ ] daily wrappers keep only expected persisted state

## 5. Paranoid minimum state
- [ ] `safe-firefox` launches
- [ ] `safe-firefox` uses the stricter arkenfox-derived local baseline
- [ ] `safe-tor-browser` launches
- [ ] `safe-mullvad-browser` launches
- [ ] browser wrappers work without broad `/run/user/$UID` exposure
- [ ] browser wrappers work without broad `/var` exposure
- [ ] portal/file chooser path is understood and tested where relevant
- [ ] `auditctl -s` shows auditing enabled and backlog limit applied
- [ ] if `myOS.security.auditRules.enable = true`, `auditctl -l` shows the repo rule set loaded
- [ ] if `myOS.security.auditRules.enable = true`, `systemctl status audit-rules-nixos.service` succeeds
- [ ] reboot happened after AppArmor was first enabled
- [ ] `aa-status` shows AppArmor active after reboot
- [ ] if any repo policy is later added, verify its complain/enforce state explicitly
- [ ] no unexpected AppArmor denial loop blocks paranoid login or wrapped-browser launch

## 6. Bubblewrap verification
For at least one browser wrapper and one daily app wrapper, inspect the running process or wrapper behavior and confirm:
- [ ] no broad home bind
- [ ] no broad `/var` bind
- [ ] private runtime dir is used
- [ ] D-Bus is filtered when enabled
- [ ] network is exposed only for wrappers that request it
- [ ] GPU is exposed only for wrappers that request it

## 7. Staged self-owned WireGuard verification (only when you explicitly enable it)
- [ ] endpoint configured as literal `IP:port`
- [ ] no hostname endpoint remains in that config
- [ ] nftables output exception is pinned to the exact endpoint IP and port
- [ ] no standing non-WG DNS exception exists
- [ ] DNS works through the tunnel
- [ ] non-WG egress is blocked when tunnel is down
- [ ] endpoint-IP change procedure in `RECOVERY.md` is understandable and testable

## 8. Security monitoring and integrity verification
- [ ] `freshclam` succeeds and ClamAV signatures update normally
- [ ] `systemctl list-timers` shows both ClamAV timers
- [ ] `systemctl start clamav-impermanence-scan` completes
- [ ] `systemctl start clamav-deep-scan` completes
- [ ] if `myOS.security.aide.enable = true`, AIDE database is initialized and `systemctl start aide-daily-check` completes
- [ ] privacy settings match the active profile: MAC randomization mode, IPv6 temporary addresses, and TCP timestamps

## 9. VM tooling and workflow verification
- [ ] libvirt starts when paranoid is active
- [ ] virt-manager launches
- [ ] creating a VM is possible
- [ ] the four VM classes are documented and understood: `trusted-work-vm`, `risky-browser-vm`, `malware-research-vm`, `throwaway-untrusted-file-vm`
- [ ] each class has explicit policy across all six layers in `PROJECT-STATE.md`
- [ ] `repo-vm-class policy <class>` matches the written policy
- [ ] `repo-vm-class create trusted-work-vm ...` produces a persistent NAT-backed VM with USB disabled by default
- [ ] `repo-vm-class create risky-browser-vm ...` produces a transient NAT-backed VM with no host share or clipboard by default
- [ ] `repo-vm-class create malware-research-vm ...` defaults to no network and rejects NAT
- [ ] `repo-vm-class create throwaway-untrusted-file-vm ...` defaults to no network and only permits explicit read-only import shares
- [ ] host defaults still match the workflow: no USB redirection by default, no implicit clipboard trust, no claim that VM tooling alone makes every guest hardened
- [ ] treat guest templates and real-world tuning as still needing live trials; do not mark any VM class fully proven until those trials are completed
- [ ] keep VM guest-template tuning in post-stability even after host-side automation is working

## 10. Secure Boot and TPM staged verification
- [ ] baseline encrypted boot works before enabling either feature
- [ ] Secure Boot enrollment works
- [ ] TPM enrollment works
- [ ] fallback recovery path is documented and understood

## 11. Performance checks
- [ ] daily gaming baseline is acceptable
- [ ] VR baseline is acceptable
- [ ] paranoid overhead is understood and acceptable
- [ ] no unexpected regression from wrapper changes

## 12. Explicit deferred validation
- [ ] `myOS.security.pamProfileBinding.enable` remains off unless explicitly staged and tested; this feature is not part of the current-stage baseline

These are not complete yet and must stay deferred:
- [ ] bubblewrap seccomp wiring
- [ ] bubblewrap Landlock wiring
- [ ] no-GPU paranoid browser variants
- [ ] deeper Tor Browser containment trials
- [ ] deeper Mullvad Browser containment trials
- [ ] retesting any Whonix-style shared machine-id idea after removal; keep this deferred in `POST-STABILITY.md` only if ever revisited
