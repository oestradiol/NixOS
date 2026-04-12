# TEST PLAN

Runtime verification checklist to run **immediately after** first boot.

For pre-install static checks and code audit, see [`PRE-INSTALL.md`](./PRE-INSTALL.md).
For recovery procedures if tests fail, see [`RECOVERY.md`](./RECOVERY.md).
For post-stability configuration, see [`POST-STABILITY.md`](./POST-STABILITY.md).

## Boot and filesystem
- [ ] system boots to daily
- [ ] system boots to paranoid specialisation
- [ ] `/` is tmpfs (`findmnt -R /`)
- [ ] `/nix`, `/persist`, `/var/log`, `/home/player`, `/home/ghost`, `/boot` are mounted as intended
- [ ] **Swap is active** (`swapon --show` shows `/swap/swapfile`, `free -h` shows swap > 0)
- [ ] reboot drops non-persisted files
- [ ] persistence verification: create file in `/tmp`, reboot, verify it's gone; create file in `~/Data`, reboot, verify it survives

## Machine ID persistence (both profiles)
- [ ] `/etc/machine-id` is persisted (check: `findmnt /etc/machine-id` shows bind from `/persist`)
- [ ] **Daily**: Machine-id is systemd-generated unique ID (check: `cat /etc/machine-id` - should NOT be `b08dfa6083e7567a1921a715000001fb`)
- [ ] **Paranoid**: Machine-id is Whonix shared ID `b08dfa6083e7567a1921a715000001fb` (check: `cat /etc/machine-id`)
- [ ] Machine-id survives reboot on both profiles (record before reboot, verify same after)

**If boot fails**: See [`RECOVERY.md`](./RECOVERY.md) "If the new system does not boot" section.
**If impermanence issues**: See [`RECOVERY.md`](./RECOVERY.md) "If impermanence causes app issues" section.

## Graphics and session
- [ ] SDDM starts (`systemctl status display-manager`)
- [ ] Plasma 6 Wayland session starts for `player`
- [ ] Plasma 6 Wayland session starts for `ghost`
- [ ] `nvidia_drm.modeset=1` is active (`cat /proc/cmdline`)

**Verification**:
```bash
systemctl --failed
journalctl -b -p warning
id && whoami && echo "$XDG_SESSION_TYPE"
```

**If NVIDIA/Wayland breaks**: See [`RECOVERY.md`](./RECOVERY.md) "If NVIDIA/Wayland breaks after update" section.

## Daily profile
- [ ] Steam starts
- [ ] Gamescope starts
- [ ] Gamemode is active (`systemctl status gamemoded`)
- [ ] VR services work (`systemctl status wivrn`)
- [ ] Vesktop run if installed
- [ ] Firefox Sync is disabled (`identity.fxaccounts.enabled = false` in about:config)
- [ ] Bluetooth controllers pair and work (Xbox/8BitDo/etc.)
- [ ] ntsync kernel module loaded (`lsmod | grep ntsync`)
- [ ] no obvious gaming regression versus current setup baseline

**If gaming performance regresses**: See [`RECOVERY.md`](./RECOVERY.md) "If gaming performance regresses" section.

## Paranoid profile
- [ ] Steam absent/disabled
- [ ] VR absent/disabled
- [ ] Vesktop absent/disabled
- [ ] `safe-firefox` launches
- [ ] `safe-tor-browser` launches
- [ ] `safe-mullvad-browser` launches
- [ ] Signal (Flatpak) launches
- [ ] separate user home is respected

## Application sandboxing
- [ ] Signal Flatpak runs on both profiles
- [ ] VRCX (safe-vrcx) runs on daily profile
- [ ] Windsurf (safe-windsurf) runs on daily profile
- [ ] Verify sandbox isolation: `ps aux | grep bwrap` shows UID 100000 processes
- [ ] Flatpak apps have desktop entries in KDE menu
- [ ] Sandboxed apps have desktop entries in KDE menu

## D-Bus filtering (paranoid profile)
- [ ] `safe-firefox` launches with D-Bus filtering enabled
- [ ] Browser extensions load correctly
- [ ] File pickers (portal) work via xdg-dbus-proxy
- [ ] Desktop notifications work (if enabled)
- [ ] No D-Bus errors in `journalctl --user -u xdg-dbus-proxy`

**If D-Bus filtering breaks functionality**: Disable in paranoid.nix: `sandbox.dbusFilter = lib.mkForce false`

## VPN and leak testing

### Daily: Mullvad App
- [ ] Mullvad daemon is running (`systemctl status mullvad-daemon`)
- [ ] Can connect to Mullvad (`mullvad status` shows Connected)
- [ ] Mullvad check shows expected VPN route (`curl https://am.i.mullvad.net/connected`)
- [ ] Firefox WebRTC does not reveal real IP (test: https://browserleaks.com/webrtc)

### Paranoid: Self-Owned WireGuard
- [ ] WireGuard interface is up (`ip link show wg-mullvad`)
- [ ] Tunnel is established (`sudo wg show wg-mullvad` shows handshake/transfer)
- [ ] Default route is via tunnel (`ip route | grep default` shows dev wg-mullvad)
- [ ] nftables policy is default-deny (`sudo nft list table inet filter | grep 'policy drop'`)
- [ ] **Endpoint-type specific nftables rules** (verify based on your endpoint):
  - **IPv4 endpoint**: `sudo nft list table inet filter | grep "ip saddr.*udp sport"` should show rule with your endpoint IP
  - **IPv6 endpoint**: `sudo nft list table inet filter | grep "ip6 saddr.*udp sport"` should show rule with your endpoint IP
  - **Hostname endpoint**: `sudo nft list table inet filter | grep "udp sport.*accept"` should show port-only rule (no IP restriction)
- [ ] **Killswitch test**: Stop WireGuard, verify egress fails, restart, verify works:
  ```bash
  sudo systemctl stop wg-quick-wg-mullvad
  curl --max-time 5 https://example.com  # Should fail
  sudo systemctl start wg-quick-wg-mullvad
  curl https://example.com  # Should succeed
  ```
- [ ] Mullvad check shows expected VPN route (`curl https://am.i.mullvad.net/connected`)
- [ ] No DNS leaks (`dig +short whoami.mullvad.net` returns Mullvad server ID)
- [ ] Tor Browser shows Tor check success

**Verification commands**:
```bash
# WireGuard status
sudo wg show wg-mullvad
ip link show wg-mullvad

# Routing
ip route | grep default

# Firewall
sudo nft list table inet filter

# DNS and IP verification
dig +short whoami.mullvad.net
curl https://am.i.mullvad.net/connected
resolvectl status
```

**If paranoid blocks too much network**: See [`RECOVERY.md`](./RECOVERY.md) "If the paranoid profile blocks too much network" section.

## Secure Boot and TPM
- [ ] signed boot succeeds (`bootctl status`, `sbctl status`)
- [ ] firmware Secure Boot shows enabled (`mokutil --sb-state`)
- [ ] recovery passphrase still works
- [ ] TPM unlock works twice in a row (`sudo systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT`)

**Verification commands**:
```bash
bootctl status
sbctl status
mokutil --sb-state || true
sudo systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT
```

**If Secure Boot breaks**: See [`RECOVERY.md`](./RECOVERY.md) "If Secure Boot breaks boot" and "If disabling Secure Boot still doesn't boot" sections.
**If TPM unlock breaks**: See [`RECOVERY.md`](./RECOVERY.md) "If TPM unlock breaks" section.

## Kernel and sysctl hardening
- [ ] `sysctl kernel.dmesg_restrict` returns 1
- [ ] `sysctl kernel.kptr_restrict` returns 2
- [ ] `sysctl kernel.yama.ptrace_scope` returns 1 on daily, 2 on paranoid
- [ ] `sysctl kernel.unprivileged_bpf_disabled` returns 1
- [ ] `sysctl fs.suid_dumpable` returns 0
- [ ] `sysctl net.ipv6.conf.all.use_tempaddr` returns 2
- [ ] `sysctl vm.swappiness` returns 150 on daily, 180 on paranoid
- [ ] `cat /proc/cmdline` includes `debugfs=off`
- [ ] `coredumpctl` shows no stored dumps / storage disabled
- [ ] `lsmod | grep -E 'dccp|sctp|rds|tipc|firewire'` returns empty

### Paranoid-only kernel controls (Madaidan-aligned)
- [ ] `sysctl kernel.kexec_load_disabled` returns 1 (paranoid only)
- [ ] `sysctl kernel.sysrq` returns 4 (paranoid only: restricted)
- [ ] `sysctl kernel.io_uring_disabled` returns 1 (paranoid only)
- [ ] `sysctl net.ipv4.tcp_timestamps` returns 0 (paranoid only; daily: 1)
- [ ] EarlyOOM is running (`systemctl status earlyoom`) — OOM killer for desktop systems

## Root and privilege hardening
- [ ] `sudo -u root whoami` works only from wheel user
- [ ] `su -` fails for non-wheel users
- [ ] `grep root /etc/shadow` shows locked (`!`) password

## USB protection (paranoid only)
- [ ] `cat /proc/cmdline` includes `usbcore.authorized_default=2` on paranoid
- [ ] keyboard and mouse still work on paranoid
- [ ] `cat /proc/cmdline` does NOT include `usbcore.authorized_default` on daily

**If USB authorization blocks peripherals**: See [`RECOVERY.md`](./RECOVERY.md) "If USB authorization blocks peripherals (paranoid)" section.

## IPv6 privacy
- [ ] `ip -6 addr` shows temporary addresses on active interfaces

## Systemd service hardening
- [ ] `systemctl show flatpak-repo | grep NoNewPrivileges` returns yes
- [ ] `systemctl show clamav-impermanence-scan | grep NoNewPrivileges` returns yes
- [ ] `systemctl show clamav-deep-scan | grep NoNewPrivileges` returns yes

## VM isolation (paranoid only)
- [ ] libvirtd service is running (`systemctl status libvirtd`)
- [ ] KVM module is loaded (`lsmod | grep kvm`)
- [ ] IOMMU is enabled in kernel logs (`dmesg | grep -i iommu`)
- [ ] User has libvirtd group access (`groups player ghost`)

## Audit tools
- [ ] `lynis audit system`
- [ ] `sudo aide --init` (initialize AIDE database - required before checks work)
- [ ] `sudo aide --check` (verify AIDE can detect file changes)
- [ ] `sudo freshclam` (update ClamAV virus definitions)
- [ ] `sudo systemctl start clamav-impermanence-scan` (test impermanence scan works)
- [ ] `sudo systemctl start clamav-deep-scan` (test deep scan works)
- [ ] review `/var/log/clamav-impermanence-scan.log` and `/var/log/clamav-deep-scan.log` for results

## Secrets and agenix
- [ ] SSH host keys exist in `/persist/etc/ssh/` (impermanence working)
- [ ] `agenix` command available
- [ ] After creating `.age` files in `/etc/nixos/secrets/`, `nixos-rebuild switch` decrypts them correctly
- [ ] WireGuard secrets decrypt to `/run/agenix/` (check: `ls -la /run/agenix/wg-private-key`)

## WireGuard dynamic endpoint refresh (hostname endpoints only)
- [ ] If using hostname endpoint: verify `dynamicEndpointRefreshSeconds` is set (check: `sudo wg show wg-mullvad` or inspect WireGuard config)
- [ ] DNS resolution refreshes periodically: monitor endpoint IP changes over time (if Mullvad rotates endpoint IPs)
- [ ] Tunnel re-establishes after endpoint IP change (if applicable)

## Recovery scenario validation (post-stability)
**Note**: These tests require inducing failure states or simulating them. Perform only after system is stable and you have recovery media ready.

### Agenix/secret decryption recovery
- [ ] **Scenario 1: Missing age identity test** (simulated):
  - Backup current SSH host key: `cp /etc/ssh/ssh_host_ed25519_key.pub /tmp/backup.pub`
  - Verify age identity extraction works: `cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age`
  - Restore backup if needed
- [ ] **Scenario 2: Secret file availability test**:
  - Verify secret files exist in `/run/agenix/` after boot
  - Verify secret files are persisted in `/persist/secrets/` (if configured)
- [ ] **Scenario 3: WireGuard secret path test**:
  - Verify WireGuard can read secret from configured path
  - Check systemd logs for agenix/WireGuard errors: `journalctl -xe | grep -i "age\|agenix\|wireguard"`

### Paranoid network failure recovery
- [ ] **Emergency disable test** (from daily profile):
  - Boot daily profile
  - Edit paranoid profile to disable WireGuard temporarily: `wireguardMullvad.enable = lib.mkForce false`
  - Rebuild and boot paranoid to verify network access without WireGuard
  - Re-enable WireGuard after test
- [ ] **Killswitch test** (already covered in VPN section above):
  - Stop WireGuard, verify egress fails
  - Restart WireGuard, verify egress succeeds

**If recovery scenarios fail**: See [`RECOVERY.md`](./RECOVERY.md) "If agenix secret decryption fails" section.

## Browser hardening verification
- [ ] Daily Firefox: `about:config` shows `privacy.resistFingerprinting` = false (FPP instead of RFP)
- [ ] Daily Firefox: `about:config` shows `media.peerconnection.enabled` = true (WebRTC enabled for gaming/video)
- [ ] Paranoid safe-firefox: check `~/.cache/safe-firefox/profile/user.js` exists with hardened prefs
- [ ] Tor Browser: verify it uses Tor network (not system DNS)
