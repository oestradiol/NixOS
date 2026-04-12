# RECOVERY

**Scope**: This document covers all major known design-time failure modes identified during development and audit. Real systems may have additional edge cases not documented here. Treat this as a comprehensive starting point, not an exhaustive list of all possible failures.

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
# Note: NO compression on swap subvolume - swapfiles must be NOCOW and non-compressed
mount -o subvol=@swap,noatime,nodatacow /dev/mapper/cryptroot /mnt/swap
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
- DNS for hostname endpoints: Persistent non-WG DNS on port 53 when using hostname endpoints (unavoidable - must resolve endpoint hostname)
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

# If not mounted from persist, impermanence bind mounts may have failed
# Check impermanence mount units
systemctl status impermanence-persist-etc-shadow.mount 2>/dev/null || echo "Mount unit not found (may use different naming)"

# Alternative: list all active impermanence-related mounts
systemctl list-units --type=mount | grep -E "(persist|impermanence)"
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

---

## If swap activation fails

**Symptom**: System boots but swap is not active (`swapon --show` empty, `free -h` shows 0 swap). May see Btrfs errors in dmesg.

**Cause**: Btrfs swapfiles require NODATACOW (no copy-on-write) and must not be compressed. If `@swap` subvolume was mounted with compression, swapfile creation/activation will fail.

**Verify the issue**:
```bash
# Check if swap is active
swapon --show
free -h

# Check swap subvolume mount options
findmnt /swap
# WRONG: shows compress=zstd
# CORRECT: shows noatime,nodatacow (NO compression)

# Check dmesg for swap errors
dmesg | grep -i "swap\|btrfs"
```

**Recovery** (installer chroot or recovery boot):
```bash
# 1. Boot installer USB, unlock LUKS, mount as in install guide
# 2. Unmount the broken swap subvolume and remount correctly
umount /mnt/swap
mount -o subvol=@swap,noatime,nodatacow /dev/mapper/cryptroot /mnt/swap

# 3. Remove old swapfile if it exists (may be corrupted)
rm -f /mnt/swap/swapfile

# 4. Recreate swapfile correctly
fallocate -l 8G /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile

# 5. Test swapfile activation before reboot
swapon /mnt/swap/swapfile && swapoff /mnt/swap/swapfile && echo "Swapfile: OK" || {
    echo "ERROR: Swapfile failed to activate"
    exit 1
}

# 6. Reboot and verify
swapon --show
free -h
```

**Prevention**: The install script now uses `noatime,nodatacow` for `@swap`. Verify before first boot with `findmnt /mnt/swap`.

---

## If WireGuard endpoint parsing fails (evaluation error)

**Symptom**: `nixos-rebuild` fails during evaluation with an assertion error about endpoint format. Build never completes.

**Error message**:
```
myOS.security.wireguardMullvad.endpoint format invalid. Must be one of:
hostname:port (e.g., us-nyc-wg-001.mullvad.net:51820),
IPv4:port (e.g., 1.2.3.4:51820),
[IPv6]:port (e.g., [2606:4700::1111]:51820)
```

**Cause**: The endpoint string in your configuration does not match any of the accepted patterns.

**Valid formats**:
- `us-nyc-wg-001.mullvad.net:51820` (hostname with port)
- `1.2.3.4:51820` (IPv4 with port)
- `[2606:4700::1111]:51820` (bracketed IPv6 with port)

**Common mistakes**:
- `2001:db8::1:51820` - Unbracketed IPv6 is ambiguous (colons in address vs colon for port)
- `hostname` - Missing port (required)
- `hostname:abc` - Non-numeric port
- `hostname:70000` - Port out of range (must be 1-65535)
- `[::1]:51820` - Actually valid, but user may have written `::1:51820`

**Recovery**:
```bash
# 1. Edit your host configuration to fix endpoint format
# Example: hosts/nixos/default.nix or your profile

# 2. Wrap IPv6 addresses in brackets
# WRONG: endpoint = "2001:db8::1:51820";
# CORRECT: endpoint = "[2001:db8::1]:51820";

# 3. Include port number
# WRONG: endpoint = "us-nyc-wg-001.mullvad.net";
# CORRECT: endpoint = "us-nyc-wg-001.mullvad.net:51820";
```

**Test before rebuild**:
```bash
# Verify your endpoint matches one of these patterns:
# hostname:port
# 1.2.3.4:port
# [IPv6]:port
```

---

## If AppArmor breaks applications

**Symptom**: Applications fail to start or behave incorrectly after enabling paranoid profile. Errors mention "apparmor", "DENIED", or "profile".

**Common affected applications**:
- Flatpak apps (AppArmor may block sandbox transitions)
- Steam/Proton (complex permission requirements)
- Custom scripts in home directory (may lack AppArmor profile)

**Verify the issue**:
```bash
# Check AppArmor denials
sudo dmesg | grep -i apparmor
sudo journalctl -xe | grep -i apparmor

# Check if profiles are loaded
sudo aa-status

# Check specific profile denials
sudo cat /sys/kernel/security/apparmor/profiles | grep -E "(steam|flatpak)"
```

**Immediate recovery** (disable AppArmor temporarily):
```bash
# Option 1: Disable AppArmor in kernel cmdline (requires reboot)
# Add to boot parameters: apparmor=0
# Or use systemd-boot editor at boot time

# Option 2: Disable AppArmor service
sudo systemctl stop apparmor
sudo systemctl disable apparmor

# Option 3: Rebuild with AppArmor disabled (persistent)
# Edit profiles/paranoid.nix or your host config:
myOS.security.apparmor = false;
nixos-rebuild switch
```

**Fine-grained recovery** (profile-specific):
```bash
# Put specific profile in complain mode (logs but allows)
sudo aa-complain /path/to/profile

# Example for Flatpak
sudo aa-complain /etc/apparmor.d/flatpak

# List profiles and their modes
sudo aa-status
```

**Root cause**: NixOS AppArmor support is still maturing. Many applications lack complete profiles, and the interaction between:
- AppArmor MAC enforcement
- Flatpak sandboxing
- bubblewrap (used by safe-* browsers)
can create unexpected denials.

**Long-term**: Report specific AppArmor denials with:
```bash
sudo dmesg | grep -i apparmor > /tmp/apparmor-denials.txt
# Include this in bug reports along with application name and action attempted
```

**Prevention**:
- Test critical applications after enabling paranoid profile
- Keep AppArmor enabled but monitor `dmesg` for denials
- Use `aa-complain` as temporary workaround for specific broken profiles

---

## If agenix secret decryption fails

**Symptom**: System fails to boot or WireGuard cannot start due to missing or undecryptable secrets. Errors mention "age" decryption failures or missing secret files.

**Common causes**:
- Missing age identity (no SSH host key or age key available)
- Lost persisted SSH host key used as age identity
- Secret file missing or not decryptable
- Paranoid WireGuard cannot come up because `privateKeyFile` path is unavailable

**The connection**: Paranoid mode depends on file-based WireGuard secrets (privateKeyFile/presharedKeyFile). The repo uses agenix for secret management, with SSH host keys as age identities. If the identity is lost or the secret file is corrupted, WireGuard cannot establish the tunnel.

**Quick diagnostic**:
```bash
# 1. Check if age identity exists
# Agenix typically uses SSH host keys as age identities
ls -la /etc/ssh/ssh_host_ed25519_key.pub
# If missing, you cannot decrypt secrets encrypted with that key

# 2. Check if secret files exist
ls -la /run/agenix/  # Runtime decrypted secrets
ls -la /persist/secrets/  # Persisted encrypted secrets (if configured)

# 3. Check WireGuard secret file availability
sudo ls -la /run/agenix/wg-private-key  # or your configured path
# If missing, WireGuard cannot start

# 4. Check systemd logs for agenix/WireGuard errors
sudo journalctl -xe | grep -i "age\|agenix\|wireguard"
```

**Recovery scenarios**:

### Scenario 1: Missing age identity (SSH host key lost)

**Cause**: The SSH host key used as the age identity was not persisted or was corrupted. Without the identity, you cannot decrypt existing secrets.

**Recovery**:
```bash
# 1. Boot installer USB, unlock LUKS, mount as in install guide

# 2. Generate a new SSH host key (this will be your new age identity)
nixos-enter
ssh-keygen -A

# 3. Extract the new age identity from the new SSH host key
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

# 4. Re-encrypt all your secrets with the new age identity
# On a trusted machine with the new age public key:
age -r age1yournewpublickey... -o secrets/wireguard-private.age <(echo "your-actual-private-key")
age -r age1yournewpublickey... -o secrets/wireguard-preshared.age <(echo "your-actual-preshared-key")

# 5. Copy the re-encrypted secrets to the persist location
cp secrets/*.age /mnt/persist/secrets/

# 6. Rebuild and reboot
nixos-enter
nixos-rebuild switch --flake /etc/nixos#nixos
```

**Prevention**: Persist SSH host keys in impermanence configuration:
```nix
# In modules/security/impermanence.nix, ensure:
/etc/ssh is persisted
```

### Scenario 2: Secret file missing or corrupted

**Cause**: The encrypted secret file was deleted, corrupted, or not copied to the correct location.

**Recovery**:
```bash
# 1. Check if you have a backup of the secret
# Look in: /persist/secrets/, your external backup, or the original machine where you generated the key

# 2. If you have the plaintext secret (from backup or original generation):
# Re-encrypt it with the current age identity
age -r $(cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age) -o /persist/secrets/wireguard-private.age <(echo "your-actual-private-key")

# 3. If you have NO backup of the secret:
# You must generate a new WireGuard key pair from Mullvad
# Follow PRE-INSTALL.md Section 15 to generate new keys and re-encrypt them

# 4. After re-encrypting, rebuild
nixos-rebuild switch --flake /etc/nixos#nixos
```

**Prevention**: Keep external backups of critical secrets (WireGuard private keys, preshared keys) in a secure location (encrypted USB, password manager, etc.).

### Scenario 3: WireGuard secret path unavailable

**Cause**: The agenix secret is not being decrypted to the expected path, or the path in the WireGuard configuration is incorrect.

**Recovery**:
```bash
# 1. Check the actual path where agenix places the decrypted secret
sudo ls -la /run/agenix/

# 2. Compare with the path configured in your WireGuard module
# In profiles/paranoid.nix or hosts/nixos/default.nix:
grep -A 5 "wireguardMullvad" /etc/nixos/hosts/nixos/default.nix
# Look for: privateKeyFile = config.age.secrets.wg-private-key.path;

# 3. Check the age secrets configuration
# In secrets/wireguard.nix or your secrets file:
cat /etc/nixos/secrets/wireguard.nix
# Verify the file path matches the WireGuard configuration

# 4. If paths don't match, fix the configuration
# Edit your secrets file to use the correct path, or edit the WireGuard config to match

# 5. Rebuild
nixos-rebuild switch --flake /etc/nixos#nixos
```

### Scenario 4: Paranoid WireGuard cannot come up (blocking all network)

**Symptom**: Paranoid profile boots but has no network connectivity. WireGuard interface is down or missing. All traffic is blocked by the killswitch.

**Recovery**:
```bash
# 1. Boot into daily profile to regain network access
# (Daily profile does not require WireGuard for basic connectivity)

# 2. Check WireGuard status on paranoid (from daily profile, after mounting paranoid subvolume)
sudo nixos-enter
ip link show wg-mullvad
sudo wg show wg-mullvad

# 3. Check if the secret file is available
ls -la /run/agenix/wg-private-key

# 4. Check agenix logs for decryption errors
journalctl -xe | grep -i "age\|agenix"

# 5. If secret is missing, follow Scenario 2 or 3 above to fix it

# 6. Once secret is available, test WireGuard manually
sudo wg-quick up wg-mullvad
sudo wg show wg-mullvad

# 7. If working, rebuild paranoid profile and reboot into it
nixos-rebuild switch --flake /etc/nixos#nixos
```

**Emergency disable** (if you need network access immediately):
```bash
# Temporarily disable WireGuard requirement in paranoid profile
# Edit profiles/paranoid.nix:
myOS.security.wireguardMullvad.enable = lib.mkForce false;
nixos-rebuild switch --flake /etc/nixos#nixos
# This will allow network access but without the paranoid WireGuard tunnel
# Use only for emergency recovery; re-enable WireGuard after fixing the secret issue
```

**Prevention**:
- Test secret decryption after first boot: `sudo ls -la /run/agenix/`
- Keep external backups of all age-encrypted secrets
- Persist SSH host keys to prevent identity loss
- Document your age identity public key in a secure location (password manager, encrypted USB)
- Test WireGuard tunnel establishment immediately after first paranoid boot
