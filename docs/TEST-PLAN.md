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
- [ ] reboot drops non-persisted files
- [ ] persistence verification: create file in `/tmp`, reboot, verify it's gone; create file in `~/Data`, reboot, verify it survives

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
- [ ] Vesktop / Telegram / Matrix run if installed
- [ ] Firefox Sync is disabled (`identity.fxaccounts.enabled = false` in about:config)
- [ ] Bluetooth controllers pair and work (Xbox/8BitDo/etc.)
- [ ] no obvious gaming regression versus current setup baseline

**If gaming performance regresses**: See [`RECOVERY.md`](./RECOVERY.md) "If gaming performance regresses" section.

## Paranoid profile
- [ ] Steam absent/disabled
- [ ] VR absent/disabled
- [ ] Vesktop absent/disabled
- [ ] Telegram absent/disabled
- [ ] Matrix absent/disabled
- [ ] `safe-firefox` launches
- [ ] Tor Browser launches
- [ ] Signal (Flatpak) launches
- [ ] separate user home is respected

## Application sandboxing
- [ ] Signal Flatpak runs on both profiles
- [ ] VRCX (safe-vrcx) runs on daily profile
- [ ] Windsurf (safe-windsurf) runs on daily profile
- [ ] Verify sandbox isolation: `ps aux | grep bwrap` shows UID 100000 processes
- [ ] Flatpak apps have desktop entries in KDE menu
- [ ] Sandboxed apps have desktop entries in KDE menu

## Mullvad and leak testing
- [ ] daily can connect to Mullvad (`mullvad status`)
- [ ] paranoid can connect to Mullvad
- [ ] paranoid loses network when Mullvad disconnects unexpectedly (disconnect VPN, verify egress fails)
- [ ] Mullvad check shows expected VPN route (`curl https://am.i.mullvad.net/connected`)
- [ ] Firefox WebRTC does not reveal real IP (test: https://browserleaks.com/webrtc)
- [ ] Tor Browser shows Tor check success

**Verification commands**:
```bash
sudo nft list ruleset
mullvad status
resolvectl status
curl https://am.i.mullvad.net/connected
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
- [ ] `cat /proc/cmdline` includes `debugfs=off`
- [ ] `coredumpctl` shows no stored dumps / storage disabled
- [ ] `lsmod | grep -E 'dccp|sctp|rds|tipc|firewire'` returns empty

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

## Browser hardening verification
- [ ] Daily Firefox: `about:config` shows `privacy.resistFingerprinting` = false (FPP instead of RFP)
- [ ] Daily Firefox: `about:config` shows `media.peerconnection.enabled` = true (WebRTC enabled for gaming/video)
- [ ] Paranoid safe-firefox: check `~/.cache/safe-firefox/profile/user.js` exists with hardened prefs
- [ ] Tor Browser: verify it uses Tor network (not system DNS)
