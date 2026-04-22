# RECOVERY

Only recovery and rollback guidance.

## 1. Daily will not boot or is unusable
- boot the previous generation from the boot menu
- if needed, boot the installer and mount the system manually
- revert the last change from a known-good generation or git state
- treat daily recovery as the first priority before debugging paranoid-specific issues

## 2. Paranoid will not boot or launch key tools
- boot the default or previous generation
- fall back to daily if daily is still usable
- compare against the last known-good generation before changing multiple surfaces at once

## 3. Secure Boot broke boot
Use this only if you explicitly enabled the staged Secure Boot path.
- disable Secure Boot in firmware temporarily
- boot a known-good unsigned path if required
- verify `bootctl status` and `sbctl status`
- if necessary, roll back the staged Secure Boot config change first and retry later

## 4. TPM unlock broke boot
Use this only if you explicitly enabled the staged TPM path.
- recover through your fallback unlock method
- inspect the `systemd-cryptenroll` state and PCR assumptions
- roll back TPM enrollment before changing unrelated layers

## 5. Machine identity changed unexpectedly
Expected baseline:
- both profiles keep their own persisted host-local machine-id
- no Whonix-style shared machine-id is part of the current repo state

Check:
- inspect `/etc/machine-id`
- inspect `/persist/etc/machine-id`
- confirm impermanence is mounted
- confirm no local override is replacing the machine-id unexpectedly

## 6. Paranoid audit or AppArmor state is wrong
Check:
- `auditctl -s`
- `aa-status`
- `systemctl status auditd`
- `journalctl -u auditd -b`

If you explicitly enabled repo custom audit rules later, also check:
- `systemctl status audit-rules-nixos.service`
- `journalctl -u audit-rules-nixos.service -b`

## 7. Staged self-owned WireGuard does not connect
Use this only if you explicitly enabled the staged self-owned WireGuard path.
Check first:
- endpoint is still literal `IP:port`
- endpoint IP has not rotated underneath the pinned rule
- private key, optional preshared key, address, and server public key all match reality
- `sudo nft list ruleset`
- `resolvectl status`

If the provider rotated the endpoint IP:
- update the pinned endpoint in the repo config
- rebuild
- retest before changing unrelated networking layers

## 8. Flatpak app issues
- confirm Flathub remote exists
- confirm portals are healthy
- check per-app Flatpak permissions before blaming the base system
- remember Flatpak is the containment layer for relatively trusted GUI apps, not the hostile-software path

## 9. `safe-firefox`, `safe-tor-browser`, or `safe-mullvad-browser` fails
Check:
- Wayland/X11 session assumptions
- GPU availability
- portal behavior
- minimal `/etc` allowlist assumptions
- per-browser persisted state for paranoid Firefox

If debugging, change one wrapper surface at a time.

## 10. Electron app wrapper fails
Check:
- portal/file chooser path
- D-Bus filtering assumptions
- app-specific Electron flags (e.g., --no-sandbox, --disable-gpu)
- X11/Wayland compatibility
- wrapper persistence assumptions

## 11. Scanner/integrity path looks wrong
- confirm `freshclam` works
- confirm ClamAV timers exist
- confirm AIDE is initialized before expecting checks to succeed
- confirm `/boot` and `/nix/var/nix/profiles` are present in `/etc/aide.conf`
- remember: current ClamAV services log detections as alerts rather than making every detection look like a generic service failure
- remember: these are persistence/file-integrity layers, not proof against an already-subverted running kernel

## 12. Cross-profile filesystem isolation looks wrong
Check:
- `mountpoint /home/<daily-user>`
- `mountpoint /home/<paranoid-user>`
- `mountpoint /persist/home/<paranoid-user>`
- `systemctl status profile-mount-invariants`

Expected:
- daily: daily user home mounted, paranoid user home paths not mounted
- paranoid: paranoid user home and persist paths mounted, daily user home not mounted
