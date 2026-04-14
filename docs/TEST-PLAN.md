# TEST PLAN

Exactly what must be tested to call the repo stable on the target machine.

## 1. Stage order
- [ ] daily is operable first
- [ ] daily is recoverable first
- [ ] paranoid validation does not block the first recovery-capable daily baseline
- [ ] after daily passes its sections, continue to paranoid minimum state

## 2. Build and boot
- [ ] `nix flake check` passes
- [ ] default system builds
- [ ] daily specialization builds
- [ ] daily boots
- [ ] paranoid boots

## 3. Persistence and identity
- [ ] `/persist` is mounted
- [ ] `/etc/machine-id` persists across reboot
- [ ] daily machine-id is unique and stable across reboot
- [ ] paranoid machine-id is unique and stable across reboot
- [ ] `/home/player` is the persistent daily home
- [ ] `/home/ghost` is tmpfs on paranoid and allowlisted persistence appears under `/persist/home/ghost`

## 4. Daily profile baseline
- [ ] Steam works
- [ ] VR path works
- [ ] controllers work
- [ ] Firefox launches normally
- [ ] `about:policies` reflects the repo-managed daily Firefox policy set
- [ ] Mullvad app mode connects and stays usable for ordinary browsing
- [ ] `services.resolved` is active and normal DNS resolution works
- [ ] Flathub remote exists and Flatpak portals work
- [ ] `fwupdmgr get-devices` works
- [ ] `safe-vrcx` launches
- [ ] `safe-windsurf` launches
- [ ] VRCX file chooser works if needed
- [ ] Windsurf file chooser works if needed

## 5. Paranoid minimum state
- [ ] `safe-firefox` launches
- [ ] `safe-firefox` uses the vendored arkenfox baseline plus repo overrides
- [ ] paranoid Firefox state persists in `.mozilla/safe-firefox`
- [ ] `safe-tor-browser` launches
- [ ] `safe-mullvad-browser` launches
- [ ] browser wrappers work without broad `/run/user/$UID` exposure
- [ ] browser wrappers work without broad `/var` exposure
- [ ] browser wrappers work with the current minimal `/etc` allowlist
- [ ] portal/file chooser behavior is tested where relevant
- [ ] `auditctl -s` shows the Linux audit subsystem active on paranoid
- [ ] `aa-status` shows AppArmor active after reboot
- [ ] no unexpected AppArmor denial loop blocks login or wrapped-browser launch

## 6. Bubblewrap verification
For at least one browser wrapper and one daily app wrapper, confirm:
- [ ] no broad home bind
- [ ] no broad `/var` bind
- [ ] private runtime dir is used
- [ ] inherited host env is not passed through wholesale
- [ ] D-Bus is filtered when enabled
- [ ] network is exposed only for wrappers that request it
- [ ] GPU is exposed only for wrappers that request it

## 7. Staged self-owned WireGuard verification
Only do this if you explicitly enable the staged self-owned WireGuard path later.
- [ ] endpoint is configured as literal `IP:port`
- [ ] no hostname endpoint remains in that config
- [ ] nftables output exception is pinned to the exact endpoint IP and port
- [ ] no standing non-WG DNS exception exists
- [ ] DNS works through the tunnel
- [ ] non-WG egress is blocked when the tunnel is down
- [ ] the endpoint-update procedure in `docs/RECOVERY.md` is understandable

## 8. Monitoring and integrity verification
- [ ] `freshclam` succeeds and signatures update normally
- [ ] `systemctl list-timers` shows both ClamAV timers
- [ ] `systemctl start clamav-impermanence-scan` completes
- [ ] `systemctl start clamav-deep-scan` completes
- [ ] ClamAV detections would be logged as alerts rather than looking like a generic service failure
- [ ] if `myOS.security.aide.enable = true`, AIDE is initialized and `systemctl start aide-daily-check` completes
- [ ] privacy settings match the active profile: MAC randomization mode, IPv6 temporary addresses, and TCP timestamps

## 9. VM tooling and workflow verification
- [ ] libvirt starts on paranoid
- [ ] virt-manager launches
- [ ] `repo-vm-class help` works
- [ ] the four VM classes are documented and understood
- [ ] `repo-vm-class policy <class>` matches `PROJECT-STATE.md`
- [ ] `repo-vm-class create trusted-work-vm ...` yields a persistent NAT-backed VM
- [ ] `repo-vm-class create risky-browser-vm ...` yields a transient NAT-backed VM with no share or clipboard by default
- [ ] `repo-vm-class create malware-research-vm ...` defaults to no network and rejects NAT
- [ ] `repo-vm-class create throwaway-untrusted-file-vm ...` defaults to no network and only permits explicit import sharing
- [ ] guest templates and guest-hardening practice are still tracked as post-stability work, not overclaimed as finished

## 10. Staged Secure Boot and TPM verification
Only after the baseline system is already stable:
- [ ] baseline encrypted boot is stable before enabling either feature
- [ ] Secure Boot enrollment works
- [ ] TPM enrollment works
- [ ] fallback recovery path is understood

## 11. Explicit deferred validation
These are not required to call the first stable baseline complete:
- [ ] repo custom audit rules re-enabled and validated
- [ ] custom AppArmor profile library
- [ ] wrapper seccomp
- [ ] wrapper Landlock
- [ ] deeper Tor Browser containment trials
- [ ] deeper Mullvad Browser containment trials
- [ ] PAM profile-binding trials
