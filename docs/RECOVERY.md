# RECOVERY

## Golden rules
- keep the LUKS recovery passphrase
- keep a recent exported copy of this repo outside the machine
- keep a bootable NixOS installer USB
- do not enable Secure Boot until one clean encrypted boot works

## If the new system does not boot
1. boot installer USB
2. unlock `NIXCRYPT`
3. mount `/mnt` exactly as in the install guide
4. `nixos-enter` or chroot as needed
5. roll back with `nixos-rebuild --rollback` if appropriate
6. check `journalctl -b -1 -p err` for errors

## If Secure Boot breaks boot
1. disable Secure Boot in firmware
2. boot the previous known-good entry or installer
3. inspect `/var/lib/sbctl`
4. rebuild and re-enroll keys only after identifying the issue
5. check `sbctl status` and `sbctl verify` for signature issues

## If disabling Secure Boot still doesn't boot (Lanzaboote nuclear recovery)
**Symptom**: Even with Secure Boot disabled in firmware, system won't boot.  
**Cause**: Lanzaboote may have corrupted boot entries or ESP contents.
```bash
# 1. Boot NixOS installer USB
# 2. Unlock and mount everything as in INSTALL-GUIDE.md Phase 2-3
sudo cryptsetup open /dev/disk/by-partlabel/NIXCRYPT cryptroot

# Mount tmpfs root (as the running system does)
mount -t tmpfs none /mnt -o mode=755,size=4G

# Create mountpoints and mount subvolumes
mkdir -p /mnt/{boot,nix,persist,var/log,home/player,persist/home/ghost,swap}
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@home-daily,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home/player
mount -o subvol=@home-paranoid,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist/home/ghost
mount -o subvol=@swap,compress=zstd,noatime /dev/mapper/cryptroot /mnt/swap
mount /dev/disk/by-partlabel/NIXBOOT /mnt/boot

sudo nixos-enter

# 3. Inside chroot, check signature status
sbctl verify  # Shows which files have signature issues
sbctl status    # Shows enrollment state

# 4. Nuclear option: reset signature database
sbctl reset     # Clears all custom keys (you'll need to re-enroll)

# 5. If Lanzaboote itself is broken, temporarily switch to standard systemd-boot
# Edit /etc/nixos/hosts/nixos/default.nix:
#   boot.loader.systemd-boot.enable = true;
#   boot.lanzaboote.enable = false;
#   myOS.security.secureBoot.enable = false;
nixos-rebuild switch

# 6. Reboot - should boot with standard systemd-boot (no Secure Boot)
# 7. Once stable, you can re-enable Lanzaboote if desired
```
**Prevention**: Keep `/persist/efi-backup-*.tar.gz` on external media before enabling Secure Boot.

## If TPM unlock breaks
1. use recovery passphrase
2. boot normally
3. inspect measured boot / changed PCR assumptions
4. re-enroll TPM only after a stable generation is active
5. `sudo systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT` to check slots

## If the paranoid profile blocks too much network (WireGuard killswitch)
1. boot default daily profile
2. edit the nftables policy in `modules/security/wireguard.nix`
3. check `sudo nft list ruleset` to identify blocking rule
4. rebuild and retest paranoid after daily is healthy again

**Emergency disable**: Boot into daily profile to regain network access, then debug the WireGuard policy in paranoid.

## If WireGuard VPN fails to connect (paranoid)
**Symptom**: WireGuard tunnel not established; no outbound connectivity.

**Common causes and fixes**:

```bash
# 1. Check WireGuard interface status
ip link show wg-mullvad
sudo wg show wg-mullvad  # Should show handshake/transfer stats

# 2. Verify systemd-resolved is working (required for bootstrap DNS)
systemctl status systemd-resolved
resolvectl status

# 3. Check DHCP is functional (required before tunnel)
ip addr show
ip route show

# 4. Check nftables rules are blocking/unblocking as expected
sudo nft list ruleset
# Look for: chain output { type filter hook output priority filter; policy drop; }
# Verify: oifname "wg-mullvad" accept is present

# 5. Check WireGuard handshake can reach endpoint
# Extract endpoint from your config and test UDP connectivity:
# (e.g., if endpoint is us-nyc-wg-001.mullvad.net:51820)
nc -vzu us-nyc-wg-001.mullvad.net 51820

# 6. If killswitch is blocking bootstrap, the issue is likely endpoint connectivity
# Check that the WireGuard endpoint is reachable and that DNS resolution works
# You cannot disable WireGuard in paranoid (enforced by governance), so fix the config
```

**Killswitch exceptions** (allowed on non-WG interfaces):
- DHCP (v4: ports 67/547, v6: ports 547/546)
- NDP (router/neighbor discovery for IPv6)
- Outbound ICMP (path MTU discovery)
- WireGuard handshake to endpoint port (UDP)

**All other traffic** must go through `wg-mullvad` interface.

**Known limitations**:
- Bootstrap DNS: Brief clearnet DNS at boot before tunnel (unavoidable - must resolve endpoint hostname)
- No automatic key rotation: Must rotate manually via Mullvad web interface
- No split tunneling: Full killswitch (all traffic through tunnel or blocked)

## If NVIDIA/Wayland breaks after update
1. boot into previous generation: `nixos-rebuild --rollback`
2. check NVIDIA driver version: `nvidia-smi`
3. check kernel logs: `dmesg | grep -i nvidia`
4. consider pinning kernel or driver version if this recurs
5. report issue to NVIDIA or NixOS channels

## If USB authorization blocks peripherals (paranoid)
1. boot daily profile to confirm hardware works
2. check `dmesg | grep -i usb` for authorization failures
3. if internal hub blocked, add device ID to allowlist in kernel params
4. temporarily disable `usbRestrict` in paranoid profile if needed

## If gaming performance regresses
1. check `swappiness` value: `sysctl vm.swappiness` (daily should be 150, paranoid 180)
2. check `ptrace_scope`: `sysctl kernel.yama.ptrace_scope` (daily should be 1)
3. disable AppArmor temporarily: `security.apparmor.enable = false` in daily profile
4. disable `init_on_alloc`: `kernelHardening.initOnAlloc = false` in daily profile
5. benchmark each change to identify the culprit

## If impermanence causes app issues
1. check app writes to non-persisted paths
2. add paths to persistence allowlist in `modules/security/impermanence.nix`
3. check `findmnt -R /` to verify mounts
4. test with a file in persisted vs non-persisted location

## If governance assertions fail at build
1. read the assertion message carefully
2. check the option in `modules/core/options.nix`
3. check the profile setting in `profiles/daily.nix` or `profiles/paranoid.nix`
4. update either the option default or the profile setting
5. ensure `PROJECT-STATE.md` reflects the intended behavior

## If login fails after reboot (mutableUsers persistence failure)

**Symptom**: "Password not surviving reboot" — password worked before reboot, now login fails. User exists but password is rejected. Password changes via `passwd` appear to work but are lost after restart.

**Root cause**: With `users.mutableUsers = true` and tmpfs root, identity files must persist to `/persist`. If persistence fails or files are corrupted, password changes are lost.

**The connection**: tmpfs root wipes `/etc` on every boot. Impermanence restores it from `/persist/etc`. If `/etc/shadow` (password hashes) isn't properly persisted, your password changes vanish on reboot:
- `mutableUsers = true` allows imperative password changes
- tmpfs root means those changes must be explicitly persisted
- Impermanence handles this, but if it's misconfigured or fails, passwords don't survive

**Quick diagnostic** (if you can still log in):
```bash
# Check if /etc/shadow is a bind mount from persist
findmnt /etc/shadow
# Expected: should show /persist/etc/shadow as the source

# If not mounted from persist, impermanence is broken
# Check impermanence status
systemctl status impermanence-daemon
```

**Critical identity files** (must persist):
- `/etc/passwd` — user accounts
- `/etc/shadow` — password hashes
- `/etc/group` — group membership
- `/etc/gshadow` — group passwords
- `/etc/subuid` — user namespace mappings
- `/etc/subgid` — group namespace mappings

**Recovery**:
```bash
# 1. Boot installer USB, unlock LUKS, mount as in install guide

# 2. Check if identity files exist on persist
ls -la /mnt/persist/etc/{passwd,shadow,group,gshadow}

# 3. If missing or empty, check backup locations:
#    - /mnt/persist/etc/ssh/ (sometimes backed up together)
#    - Your external backup of /persist

# 4. Emergency user recreation (if no backup available):
nixos-enter
groupadd -g 1000 player
useradd -u 1000 -g 1000 -G wheel,audio,video,input,libvirtd -m player
passwd player  # Set new password
```

**Prevention**: Verify persistence is working before relying on imperative user management:
```bash
# On running system: make a test change, verify it persists
grep "testuser" /etc/passwd || sudo useradd testuser
# reboot, then: grep "testuser" /etc/passwd
```

---

## If systemd services fail after reboot (machine-id/systemd state)

**Symptom**: Services fail to start, journal shows machine-id warnings, systemd state appears inconsistent.

**Current design**: Both profiles now persist machine-id for operational stability:
- **Daily**: Systemd generates a unique stable ID at first boot
- **Paranoid**: Uses the **Whonix shared machine-id** (`b08dfa6083e7567a1921a715000001fb`) for privacy

The Whonix ID blends your system with all Whonix users rather than being uniquely fingerprintable, while remaining stable for systemd state consistency.

**Design rationale**: 
- `/var/lib/systemd` is persisted because it contains:
  - Service enablement/disablement state
  - Timer last-run timestamps
  - Some runtime tracking that NixOS expects to survive reboots
- Machine-id is persisted on both profiles to avoid operational issues
- Paranoid uses the shared Whonix ID for privacy (not unique per boot)

**Reference**: https://github.com/Whonix/dist-base-files/blob/master/etc/machine-id

**Recovery** (if services actually break):
```bash
# 1. Check current machine-id vs persisted systemd state
cat /etc/machine-id
ls -la /var/lib/systemd/

# 2. If services are broken, clear systemd state (it regenerates):
sudo systemctl stop systemd-timesyncd  # stop services first
sudo rm -rf /var/lib/systemd/timesync /var/lib/systemd/random-seed
# Or clear all systemd state (nuclear option):
sudo rm -rf /var/lib/systemd/*

# 3. Reboot - systemd regenerates fresh state

# 4. Alternative: check if machine-id mismatch is the cause
# Compare the machine-id in /etc/machine-id with what systemd expects
# If mismatch, the systemd state may need clearing as above
```

**Decision**: Current design uses stable machine-id for both profiles. Daily gets unique systemd-generated ID; paranoid gets Whonix shared ID for privacy (blends with all Whonix users rather than being unique per boot). No operational issues.

---

## If D-Bus filtering breaks browser functionality (paranoid)
**Symptom**: safe-firefox, safe-tor, or safe-mullvad-browser fail to start, file picker doesn't work, or portals break after browser/KDE update.

**Common causes**:
- Tor/Mullvad Browser changed D-Bus namespace (MONITOR: gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050)
- xdg-dbus-proxy failing to start
- KDE portal interface changes after Plasma updates

**Recovery steps**:
```bash
# 1. Check D-Bus proxy errors in logs
journalctl --user -u xdg-dbus-proxy
journalctl -xe | grep -i dbus

# 2. Test browser without D-Bus filtering (temporary)
# Edit profiles/paranoid.nix:
myOS.security.sandbox.dbusFilter = lib.mkForce false;
nixos-rebuild switch

# 3. If browser works without filtering, the D-Bus policy needs updating
# Check browser.nix for the dbusOwnName setting and compare with:
grep dbusOwnName modules/security/browser.nix

# 4. For KDE portal issues, check what interfaces changed:
grep -r "org.freedesktop.portal" /usr/share/dbus-1/
# Update browser.nix --talk and --broadcast rules as needed
```

**Prevention**: Test safe-* browsers after every KDE Plasma or browser update before rebooting into paranoid profile permanently.
