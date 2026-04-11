# TEST PLAN

## Boot and filesystem
- [ ] system boots to daily
- [ ] system boots to paranoid specialisation
- [ ] `/` is tmpfs
- [ ] `/nix`, `/persist`, `/var/log`, `/home/player`, `/home/ghost`, `/boot` are mounted as intended
- [ ] reboot drops non-persisted files

## Graphics and session
- [ ] SDDM starts
- [ ] Plasma 6 Wayland session starts for `player`
- [ ] Plasma 6 Wayland session starts for `ghost`
- [ ] `nvidia_drm.modeset=1` is active

## Daily profile
- [ ] Steam starts
- [ ] Gamescope starts
- [ ] VR services work
- [ ] Vesktop / Telegram / Matrix run if installed
- [ ] Firefox Sync can be used manually
- [ ] no obvious gaming regression versus current setup baseline

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
- [ ] Flatpak apps have desktop entries in KDE menu
- [ ] Sandboxed apps have desktop entries in KDE menu

## Mullvad and leak testing
- [ ] daily can connect to Mullvad
- [ ] paranoid can connect to Mullvad
- [ ] paranoid loses network when Mullvad disconnects unexpectedly
- [ ] Mullvad check shows expected VPN route
- [ ] Firefox WebRTC does not reveal real IP
- [ ] Tor Browser shows Tor check success

## Secure Boot and TPM
- [ ] signed boot succeeds
- [ ] firmware Secure Boot shows enabled
- [ ] recovery passphrase still works
- [ ] TPM unlock works twice in a row

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

## IPv6 privacy
- [ ] `ip -6 addr` shows temporary addresses on active interfaces

## Systemd service hardening
- [ ] `systemctl show flatpak-repo | grep NoNewPrivileges` returns yes
- [ ] `systemctl show clamav-daily-scan | grep NoNewPrivileges` returns yes

## Audit tools
- [ ] `lynis audit system`
- [ ] `aide --init` then follow-up check after baseline
- [ ] optional `clamdscan` only if you decide it is worth it
