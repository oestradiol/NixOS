# TEST PLAN

Exactly what must be tested to call the repo stable on the target machine.
These checks are the runtime proof layer for this specific hardware, not just a static repo review.

## How to Run Tests

The repo includes a test suite runnable from any checkout:

```bash
# Run all tests (static + runtime + bugs)
./tests/run.sh

# Run only static tests (no booted machine required, safe to run anywhere)
./tests/run.sh --layer static

# Run only runtime tests (requires booted target system)
./tests/run.sh --layer runtime

# Run only bug regression tests
./tests/run.sh --layer bugs

# Run specific test file
./tests/run.sh tests/static/010-flake-check.sh

# Verbose output (stream as they run)
./tests/run.sh --verbose

# Skip tests requiring sudo
./tests/run.sh --no-sudo
```

### Test Layers Explained

**Static tests** — Validate framework repository itself:
- Flake evaluation, governance assertions, profile deltas
- File structure, documentation accuracy
- No booted machine required; runs in CI or any checkout

**Runtime tests** — Validate your booted system:
- Discovers active profile from running system
- Tests validate framework options are correctly applied
- Template-agnostic: works with any user names in `myOS.users`

**Bugs tests** — Regression tests for known historical bugs

### Testing Custom Flakes

If you used the framework to build a custom flake:

1. **Static tests on framework source** (run against the framework repo):
   ```bash
   cd /path/to/framework/repo
   ./tests/run.sh --layer static
   ```

2. **Runtime tests on your booted system** (run from your installed flake):
   ```bash
   # Copy the tests directory to your installed system
   cp -r /path/to/framework/repo/tests /etc/nixos/
   cd /etc/nixos/tests
   ./run.sh --layer runtime
   ```

Runtime tests auto-discover your active profile and users from the running system's configuration — they work with any `myOS.users.*` definitions.

## Validation Checklist

Use this checklist to validate your installation. Mark items as you complete them:
- `[X]` = Passed/Verified
- `[ ]` = Not yet tested
- `[-]` = Skipped (not applicable to your config)

## 1. Stage order
- [X] daily is operable first

## 2. Build and boot
- [X] `nix flake check` passes
- [X] default system builds on the target machine
- [X] daily specialization builds on the target machine
- [X] the expected host hardware target file still matches the actual machine
- [X] encrypted boot works on the target machine
- [X] daily boots
- [ ] paranoid boots
- [X] at least one rollback generation is available after first successful activation

## 3. Login, desktop, and session baseline
- [X] greetd/regreet greeter appears reliably after boot
- [X] daily user(s) can log into the daily profile successfully
- [ ] paranoid user(s) can log into the paranoid profile successfully
- [X] Plasma starts cleanly on daily
- [X] logout and re-login work on daily
- [X] no login loop or session-crash loop appears after reboot on daily

## 4. Persistence, mounts, and identity
- [X] `/persist` is mounted
- [X] `/etc/machine-id` persists across reboot
- [X] daily machine-id is unique and stable across reboot
- [ ] paranoid machine-id is unique and stable across reboot
- [X] daily-style user homes are persistent (Btrfs-backed)
- [ ] paranoid-style user homes are tmpfs with allowlisted persistence under `/persist/home/`
- [X] daily does not mount paranoid user home surfaces
- [ ] paranoid does not mount daily user home surfaces
- [X] the opposite profile home paths are absent from `/proc/mounts`
- [X] `systemctl status profile-mount-invariants` succeeds on both profiles

## 5. Daily profile baseline
- [X] Firefox launches normally
- [X] `about:policies` reflects the repo-managed daily Firefox policy set
- [X] Mullvad app mode connects and stays usable for ordinary browsing
- [X] `services.resolved` is active and normal DNS resolution works
- [X] Flathub remote exists and Flatpak portals work
- [X] Signal Flatpak installs and launches if Signal is in the baseline app set
- [X] Bitwarden Flatpak installs and launches if Bitwarden is in the baseline app set
- [X] any other baseline-critical Flatpak app is listed explicitly and tested explicitly
- [X] Steam works
- [N/A] controllers work (no controller hardware detected)
- [N/A] VR path works if VR is part of the first stable baseline for this machine (wivrn requires avahi for auto-discovery; with lanDiscovery.enable=false, headset must connect by IP manually - service fails without avahi, which is expected design)
- [X] `fwupdmgr get-devices` works

## 6. Recovery and operator-proof baseline (can test now)
- [ ] `nixos-rebuild` works from the daily profile
- [ ] rollback to a prior generation works
- [ ] a broken paranoid change does not remove the ability to reach a working daily state
- [ ] the recovery steps in `docs/pipeline/RECOVERY.md` are understandable enough to follow on the real machine

## 7. Audio, input, and desktop integration
- [X] speaker output works
- [X] microphone input works
- [X] `systemctl --user status pipewire wireplumber` is healthy in both profiles where audio is expected
- [X] fcitx5 starts correctly where expected
- [X] Japanese input works in at least one app where expected
- [X] notifications work for the baseline apps that rely on them (Plasma built-in notification system)
- [X] portal-based open/save flows work for the baseline apps that rely on them

## 8. GPU and hardware-specific proof
- [X] the expected GPU driver is loaded on the target machine
- [X] hardware acceleration works in Firefox on the target machine
- [X] the intended Wayland path is stable enough for normal use on the target machine
- [X] gamescope works on the target machine if daily gaming is baseline-critical
- [X] Steam 32-bit graphics path works if Steam is baseline-critical
- [X] the current firmware / UEFI behavior matches the install assumptions

## 9. Paranoid minimum state
- [ ] `safe-firefox` launches
- [ ] `safe-firefox` uses the vendored arkenfox baseline plus repo overrides
- [ ] paranoid Firefox state persists in `.mozilla/safe-firefox`
- [ ] `safe-tor-browser` launches
- [ ] `safe-mullvad-browser` launches
- [ ] browser wrappers work without broad `/run/user/$UID` exposure
- [ ] browser wrappers work without broad `/var` exposure
- [ ] browser wrappers work with the current minimal `/etc` allowlist
- [ ] notifications and portal/file chooser behavior are tested where relevant
- [ ] Signal Flatpak launches on paranoid if Signal remains part of the paranoid baseline
- [ ] `auditctl -s` shows the Linux audit subsystem active on paranoid
- [ ] `aa-status` shows AppArmor active after reboot
- [ ] no unexpected AppArmor denial loop blocks login or wrapped-browser launch

## 10. Bubblewrap verification
For at least one browser wrapper and one daily app wrapper, confirm:
- [ ] no broad home bind
- [ ] no broad `/var` bind
- [ ] private runtime dir is used
- [ ] inherited host env is not passed through wholesale
- [ ] D-Bus is filtered when enabled
- [ ] network is exposed only for wrappers that request it
- [ ] GPU is exposed only for wrappers that request it
- [ ] the wrapper uses the intended `etcMode` and allowlist for its role

## 11. Staged self-owned WireGuard verification
Only do this if you explicitly enable the staged self-owned WireGuard path later.
- [ ] endpoint is configured as literal `IP:port`
- [ ] no hostname endpoint remains in that config
- [ ] nftables output exception is pinned to the exact endpoint IP and port
- [ ] no standing non-WG DNS exception exists
- [ ] DNS works through the tunnel
- [ ] non-WG egress is blocked when the tunnel is down
- [ ] the endpoint-update procedure in `docs/pipeline/RECOVERY.md` is understandable

## 12. Privacy settings (can test now)
- [ ] privacy settings match the active profile: MAC randomization mode, IPv6 temporary addresses, and TCP timestamps

## 13. Monitoring and integrity verification (staged features)
- [ ] `freshclam` succeeds and signatures update normally
- [ ] `systemctl list-timers` shows both ClamAV timers
- [ ] ClamAV target set covers durable state and boot surfaces rather than tmpfs-only churn
- [ ] daily ClamAV target generation excludes paranoid user home paths entirely
- [ ] paranoid ClamAV target generation excludes daily user home paths entirely
- [ ] `systemctl start clamav-impermanence-scan` completes
- [ ] `systemctl start clamav-deep-scan` completes
- [ ] ClamAV detections would be logged as alerts rather than looking like a generic service failure
- [ ] if `myOS.security.aide.enable = true`, AIDE is initialized and `systemctl start aide-daily-check` completes
- [ ] AIDE configuration is restricted to stable, high-signal trust surfaces rather than noisy home/app trees
- [ ] AIDE configuration includes `/boot` and `/nix/var/nix/profiles` in addition to selected persisted identity/trust state

## 14. VM tooling and workflow verification
- [ ] libvirt starts on paranoid
- [ ] virt-manager launches
- [ ] `repo-vm-class help` works
- [ ] the four VM classes are documented and understood
- [ ] `repo-vm-class policy <class>` matches `docs/governance/PROJECT-STATE.md`
- [ ] repo NAT network exists and comes up
- [ ] repo isolated network exists and comes up
- [ ] `repo-vm-class create trusted-work-vm ...` yields a persistent NAT-backed VM
- [ ] `repo-vm-class create risky-browser-vm ...` yields a transient NAT-backed VM with no share or clipboard by default
- [ ] destroying a transient VM removes its transient overlay image
- [ ] `repo-vm-class create malware-research-vm ...` defaults to no network and rejects NAT
- [ ] `repo-vm-class create throwaway-untrusted-file-vm ...` defaults to no network and only permits explicit import sharing
- [ ] guest templates and guest-hardening practice are still tracked as post-stability work, not overclaimed as finished

## 15. Secrets and staged secure boot / TPM verification
- [ ] agenix does not block the baseline build if no required secrets are missing
- [ ] any secrets that are baseline-required are present and decrypt correctly on target
Only after the baseline system is already stable:
- [ ] baseline encrypted boot is stable before enabling either feature
- [ ] Secure Boot enrollment works
- [ ] TPM enrollment works
- [ ] fallback recovery path is understood

## 16. Explicit deferred validation
These are not required to call the first stable baseline complete:
- [ ] repo custom audit rules re-enabled and validated
- [ ] custom AppArmor profile library
- [ ] wrapper seccomp
- [ ] wrapper Landlock
- [ ] deeper Tor Browser containment trials
- [ ] deeper Mullvad Browser containment trials
