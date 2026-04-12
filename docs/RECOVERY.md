# RECOVERY

**Scope**: This document covers all major known design-time failure modes identified during development and audit. Real systems may have additional edge cases not documented here. Treat this as a comprehensive starting point, not an exhaustive list of all possible failures.

## Mount context discipline

**Critical**: Recovery commands must distinguish between:
- **Live system**: Commands run from your running NixOS installation (paths like `/`, `/persist`, `/nix`)
- **Installer environment**: Commands run from NixOS installer USB after mounting target to `/mnt`

This doc marks commands with context where ambiguous:
- `# (from live system: use /; from installer: use /mnt)` - Adjust path accordingly
- `# Inside the nixos-enter shell` - Commands run inside chroot, not from live installer

When in doubt, check your current context:
```bash
# Check if you're in installer or live system
test -d /mnt && echo "Installer context" || echo "Live system context"
```

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
- **Daily**: Systemd generates a unique stable ID at first boot (follows systemd's unique-id guidance)
- **Paranoid**: Uses the **Whonix shared machine-id** (`b08dfa6083e7567a1921a715000001fb`) for privacy

The Whonix ID blends your system with all Whonix users rather than being uniquely fingerprintable, while remaining stable for systemd state consistency. This is a deliberate privacy exception that conflicts with systemd's unique-id guidance (machine-id should be unique per host).

**Design rationale**:
- `/var/lib/systemd` is persisted because it contains:
  - D-Bus machine ID
  - User runtime directories
  - Timer last-run timestamps
  - Some runtime tracking that NixOS expects to survive reboots
- Machine-id is persisted on both profiles to avoid operational issues
- Paranoid uses the shared Whonix ID for privacy (deliberate exception to systemd's unique-id guidance)

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

**Decision**: Current design uses stable machine-id for both profiles. Daily gets unique systemd-generated ID (follows systemd guidance); paranoid gets Whonix shared ID for privacy (deliberate exception to systemd's unique-id guidance, blends with all Whonix users rather than being unique per boot). No operational issues.

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

---

## If Nix trusted users configuration causes issues

**Symptom**: Nix operations fail, permission errors, or unexpected privilege escalation.

**Common causes**:
- User incorrectly added to `trusted-users` in `modules/core/base-desktop.nix`
- Manual configuration error added unintended user to trusted-users

**The connection**: Nix `trusted-users` is hardcoded to `["root"]` in `modules/core/base-desktop.nix` for both profiles. Upstream Nix warns that adding users to trusted-users is essentially equivalent to giving them root access for Nix operations (build as root, bypass sandbox restrictions, set configuration options, perform garbage collection as root). This repo uses the minimal safe default to reduce attack surface.

**Quick diagnostic**:
```bash
# 1. Check current Nix trusted users configuration
nix show-config | grep trusted-users

# 2. Check base-desktop.nix configuration
grep -A 5 "trusted-users" /etc/nixos/modules/core/base-desktop.nix
```

**Recovery**:

### Scenario 1: Accidentally added user to trusted-users

**Cause**: Manual modification of `modules/core/base-desktop.nix` added unintended user.

**Recovery**:
```bash
# 1. Restore safe default
# Edit modules/core/base-desktop.nix:
nix.settings = {
  ...
  trusted-users = [ "root" ];  # Restore minimal safe default
  ...
}

# 2. Rebuild
nixos-rebuild switch --flake /etc/nixos#nixos
```

### Scenario 2: Need to add user for Steam/development workflow

**Cause**: Steam or development workflow requires user in trusted-users.

**Recovery**:
```bash
# 1. Modify base-desktop.nix to add your user
# Edit modules/core/base-desktop.nix:
nix.settings = {
  ...
  trusted-users = [ "root" "player" ];  # Add your user
  ...
}

# 2. Rebuild
nixos-rebuild switch --flake /etc/nixos#nixos

# 3. Understand the security implications:
# - This gives player root-equivalent Nix privileges
# - They can build as root, bypass sandbox restrictions, set config, perform GC as root
# - This is a deliberate security tradeoff for workflow convenience
```

**Prevention**:
- Keep `trusted-users = [ "root" ]` as the default minimal safe setting
- Only modify if you understand the security implications
- Document any deviations from the default
- Use sudo for Nix operations when possible instead of adding users to trusted-users

---

## If /persist fails to mount

**Symptom**: System boots but critical persisted files are missing, or boot fails with mount errors for /persist.

**Causes**:
- Btrfs subvolume @persist missing or corrupted
- LUKS device not unlocking
- Mount option mismatch (compression, nodatacow)
- Impermanence mount unit misconfiguration

**Diagnostics**:
```bash
# Check if /persist is mounted (from live system)
findmnt /persist

# Check Btrfs subvolumes (from live system: use /; from installer: use /mnt)
sudo btrfs subvolume list /

# Check if LUKS device is open
lsblk -f
sudo cryptsetup status cryptroot

# Check systemd mount units
systemctl status local-fs.target
systemctl status -.mount
journalctl -xe | grep -i persist
```

**Recovery**:

### Scenario 1: Subvolume missing

**Cause**: @persist subvolume was deleted or never created.

**Recovery**:
```bash
# 1. Boot NixOS installer USB
sudo cryptsetup open /dev/disk/by-partlabel/NIXCRYPT cryptroot

# Mount root
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt

# 2. Create missing @persist subvolume
sudo btrfs subvolume create /mnt/@persist

# 3. Reboot
umount /mnt
cryptsetup close cryptroot
reboot
```

### Scenario 2: LUKS not unlocking

**Cause**: Wrong passphrase or TPM enrollment issue.

**Recovery**: See "If TPM unlock breaks" section above for TPM recovery. For passphrase issues, use recovery passphrase.

### Scenario 3: Mount option mismatch

**Cause**: Subvolume was created with different options than config expects.

**Recovery**:
```bash
# Check current mount options
findmnt -o OPTIONS /persist

# If compression is wrong, remount with correct options
# Edit hosts/nixos/default.nix to match actual subvolume state
# Or recreate subvolume with correct options
```

**Prevention**:
- Verify subvolume creation after install: `sudo btrfs subvolume list /`
- Keep LUKS passphrase in secure location
- Test TPM unlock immediately after enrollment
- Keep backup of subvolume layout

---

## If /nix mount or store is corrupted

**Symptom**: `nixos-rebuild` fails, package installation errors, store corruption messages.

**Causes**:
- Btrfs @nix subvolume corruption
- Nix store database corruption
- Disk failure
- Power loss during write

**Diagnostics**:
```bash
# Check Btrfs health (from live system: use /; from installer: use /mnt)
sudo btrfs filesystem status /
sudo btrfs scrub start /

# Check Nix store
nix-store --verify --check-contents --repair
nix-collect-garbage -d

# Check for read-only remount
mount | grep /nix
```

**Recovery**:

### Scenario 1: Btrfs corruption on @nix

**Cause**: Btrfs checksum errors or metadata corruption.

**Recovery**:
```bash
# 1. Run scrub to detect and repair
sudo btrfs scrub start -B -R /

# 2. If scrub reports errors, check dmesg
dmesg | grep -i btrfs

# 3. If uncorrectable errors, may need to recreate @nix subvolume
# WARNING: This requires rebuilding all packages
# Boot installer, mount system, backup config, recreate subvolume, rebuild
```

### Scenario 2: Nix store database corruption

**Cause**: Nix store database files corrupted.

**Recovery**:
```bash
# 1. Attempt repair
nix-store --verify --check-contents --repair

# 2. If that fails, clear and rebuild
nix-collect-garbage -d
nixos-rebuild switch --option substituters ""  # Rebuild from source
```

### Scenario 3: Read-only remount

**Cause**: Btrfs remounted read-only due to errors.

**Recovery**:
```bash
# 1. Check why it remounted read-only
dmesg | grep -i btrfs

# 2. Remount read-write temporarily
sudo mount -o remount,rw /

# 3. Run scrub to fix underlying issue
sudo btrfs scrub start /
```

**Prevention**:
- Run periodic Btrfs scrubs
- Monitor dmesg for Btrfs errors
- Use UPS to prevent power loss
- Keep backups of critical Nix store paths

---

## If EFI boot entry is lost

**Symptom**: System boots directly to firmware/BIOS, no boot menu, or wrong OS boots.

**Causes**:
- Firmware reset cleared boot entries
- Firmware update removed boot entries
- Bootloader installation corrupted
- EFI system partition corrupted

**Diagnostics**:
```bash
# Check boot entries (from running system or installer USB)
bootctl list

# Check EFI system partition
lsblk -f
sudo fatlabel /dev/disk/by-partlabel/NIXBOOT

# Check Secure Boot status
sbctl status
```

**Recovery**:

### Scenario 1: Boot entries lost after firmware reset

**Cause**: Firmware reset/clear NVRAM removed NixOS boot entries.

**Recovery**:
```bash
# 1. Boot NixOS installer USB
# 2. Mount system as in INSTALL-GUIDE.md Phase 2-3
sudo cryptsetup open /dev/disk/by-partlabel/NIXCRYPT cryptroot
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist
mount /dev/disk/by-partlabel/NIXBOOT /mnt/boot

# 3. Bind mount for nixos-enter
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# 4. Enter the target system (this drops you into a shell inside /mnt)
nixos-enter --root /mnt

# Inside the nixos-enter shell, run:
nixos-rebuild switch --install-bootloader --flake /etc/nixos#nixos

# Exit the nixos-enter shell when done:
exit

# 5. Verify entries (back in live installer environment)
bootctl list
```

### Scenario 2: EFI system partition corrupted

**Cause**: ESP filesystem corruption or deletion.

**Recovery**:
```bash
# 1. Boot NixOS installer USB
# 2. Recreate ESP (WARNING: This deletes all ESP contents)
sudo mkfs.vfat -F32 /dev/disk/by-partlabel/NIXBOOT

# 3. Mount system as in INSTALL-GUIDE.md Phase 2-3
sudo cryptsetup open /dev/disk/by-partlabel/NIXCRYPT cryptroot
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist
mount /dev/disk/by-partlabel/NIXBOOT /mnt/boot

# 4. Bind mount for nixos-enter
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# 5. Enter the target system (this drops you into a shell inside /mnt)
nixos-enter --root /mnt

# Inside the nixos-enter shell, run:
nixos-rebuild switch --install-bootloader --flake /etc/nixos#nixos

# Exit the nixos-enter shell when done:
exit

# 6. Verify entries (back in live installer environment)
bootctl list
```

### Scenario 3: Secure Boot keys lost

**Cause**: Secure Boot keys cleared from firmware.

**Recovery**: See "If disabling Secure Boot still doesn't boot (Lanzaboote nuclear recovery)" section above.

**Prevention**:
- Keep backup of EFI ESP before firmware updates
- Document boot entry configuration
- Keep Secure Boot recovery keys backed up
- Test firmware updates in safe environment first

---

## If NetworkManager state corruption

**Symptom**: Network connections fail, cannot connect to VPN, WiFi issues.

**Causes**:
- NetworkManager configuration corruption
- Connection profiles corrupted
- State file corruption

**Diagnostics**:
```bash
# Check NetworkManager status
systemctl status NetworkManager

# Check connections
nmcli connection show

# Check logs
journalctl -xeu NetworkManager
```

**Recovery**:

### Scenario 1: Connection profiles corrupted

**Cause**: NetworkManager connection files corrupted.

**Recovery**:
```bash
# 1. Backup current connections
sudo cp -r /etc/NetworkManager/system-connections /tmp/

# 2. Remove problematic connections
sudo rm /etc/NetworkManager/system-connections/bad-connection.nmconnection

# 3. Restart NetworkManager
sudo systemctl restart NetworkManager

# 4. Recreate connections via nmcli or GUI
```

### Scenario 2: State file corruption

**Cause**: NetworkManager state file corrupted.

**Recovery**:
```bash
# 1. Stop NetworkManager
sudo systemctl stop NetworkManager

# 2. Remove state file
sudo rm /var/lib/NetworkManager/NetworkManager.state

# 3. Restart NetworkManager
sudo systemctl start NetworkManager
```

**Prevention**:
- Keep backup of NetworkManager connections
- Document critical connection configurations
- Monitor NetworkManager logs for errors

---

## If rollback across generations has persistence issues

**Symptom**: Rolling back to previous generation causes persistence issues, missing files, or configuration mismatches.

**Causes**:
- Schema drift between generations
- Persistence paths changed
- Impermanence configuration changed
- Subvolume layout changed

**Diagnostics**:
```bash
# Check current generation
nixos-rebuild --list-generations

# Check persistence configuration
grep -r "impermanence" /etc/nixos/

# Compare generations
nixos-rebuild switch --rollback
# Check if issues occur
```

**Recovery**:

### Scenario 1: Persistence path changed

**Cause**: Impermanence configuration added/removed paths between generations.

**Recovery**:
```bash
# 1. Identify what changed between generations
nixos-rebuild --list-generations
# Compare current generation with previous generation
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
# View configuration diff:
sudo git -C /etc/nixos diff HEAD~1 HEAD

# 2. Update current generation config to match persistence expectations
# Edit modules/security/impermanence.nix to align paths

# 3. Rebuild
nixos-rebuild switch
```

### Scenario 2: Subvolume layout changed

**Cause**: Btrfs subvolume structure changed between generations.

**Recovery**:
```bash
# 1. Check current subvolume layout (from live system or installer)
sudo btrfs subvolume list /

# Expected subvolume paths/names for this repo:
# @ (root)
# @home
# @persist
# @nix
# @swap

# Note: Subvolume IDs are not stable; focus on path names instead.

# 2. Compare with expected layout from config
# Check hosts/nixos/default.nix for subvolume definitions

# 3. Create missing subvolumes (example for @persist)
sudo btrfs subvolume create /@persist

# 4. Or update config to match actual layout if subvolume naming changed
# Edit hosts/nixos/default.nix to use actual subvolume names

# 5. Rebuild
nixos-rebuild switch
```

**Prevention**:
- Document persistence configuration changes
- Test persistence changes before committing
- Keep backup of critical persisted data
- Use git to track configuration changes

---

## General subvolume mismatch or mount-option drift

**Symptom**: Mount errors, wrong filesystem mounted, options not applied.

**Causes**:
- Subvolume names changed
- Mount options changed in config
- fstab entries mismatched
- Impermanence mount unit misconfiguration

**Diagnostics**:
```bash
# Check all mounts (from live system)
findmnt -R

# Check Btrfs subvolumes (from live system: use /; from installer: use /mnt)
sudo btrfs subvolume list /

# Check systemd mount units
systemctl list-units --type=mount

# Check expected vs actual
grep -r "subvol=" /etc/nixos/
```

**Recovery**:

### Scenario 1: Subvolume name mismatch

**Cause**: Config expects subvolume name that doesn't exist.

**Recovery**:
```bash
# 1. Check what subvolumes exist (from live system: use /; from installer: use /mnt)
sudo btrfs subvolume list /

# 2. Identify expected subvolume name from config
grep -r "subvol=" /etc/nixos/hosts/nixos/default.nix

# 3. Option A: Create missing subvolume (example for @persist)
# From live system:
sudo btrfs subvolume create /@persist
# From installer (after mounting to /mnt):
sudo btrfs subvolume create /mnt/@persist

# 4. Option B: Update config to use existing subvolume
# Edit hosts/nixos/default.nix to use actual subvolume name

# 5. Rebuild
nixos-rebuild switch
```

### Scenario 2: Mount option drift

**Cause**: Mount options in config don't match actual subvolume state.

**Recovery**:
```bash
# 1. Check current mount options
findmnt -o OPTIONS /persist

# 2. Check expected options from config
grep -A 10 "fileSystems.\"/persist\"" /etc/nixos/hosts/nixos/default.nix

# Expected options for this repo:
# options = [ "subvol=@persist" "compress=zstd" "noatime" ]

# 3. Option A: Remount with correct options (temporary)
sudo mount -o remount,compress=zstd,noatime /persist

# 4. Option B: Update config to match actual subvolume requirements
# Edit hosts/nixos/default.nix to match actual subvolume state

# 5. Rebuild
nixos-rebuild switch
```

**Prevention**:
- Document subvolume layout
- Use consistent naming conventions
- Test mount configuration changes
- Keep backup of fstab/mount units
