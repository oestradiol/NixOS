# AUDIT

Runtime verification tutorial, failure modes, and code map — merged into one surface.

## The rule
Never trust a status line by itself. For each claim, check four layers:
- **Docs**: what the repo says should happen
- **Code**: which file is supposed to do it
- **Build**: whether the config evaluates
- **Runtime**: whether the machine actually behaves that way

## Code map

### Boot / kernel / platform
- `modules/core/boot.nix` — bootloader, kernel params, gaming sysctls
- `modules/core/options.nix` — all `myOS.*` option declarations
- `modules/security/base.nix` — hardened sysctls, module blacklist, coredump, root lock
- `modules/security/secure-boot.nix` — Lanzaboote + TPM
- `hosts/nixos/hardware-target.nix`, `hosts/nixos/install-layout.nix`

### User / session
- `modules/core/users.nix` — player, ghost, sudo config
- `modules/core/base-desktop.nix` — desktop env, locale, nix, audio, system health
- `modules/home/daily.nix`, `modules/home/paranoid.nix`
- `profiles/daily.nix`, `profiles/paranoid.nix`

### Storage / persistence / secrets
- `modules/security/impermanence.nix`
- `modules/security/secrets.nix`

### Networking / browser / privacy
- `modules/security/networking.nix` — killswitch, nftables
- `modules/security/browser.nix` — sandboxed browser wrappers (UID 100000, bubblewrap)
  - `safe-firefox`: Hardened Firefox with arkenfox-grounded user.js (70+ prefs)
  - `safe-tor-browser`, `safe-mullvad-browser`: Sandboxed Tor/Mullvad
- `modules/security/flatpak.nix` — flatpak + xdg portals
- `modules/home/paranoid.nix` — signal-desktop only; browsers via system wrappers

### Gaming
- `modules/desktop/gaming.nix` — Steam, gamescope, gamemode
- `modules/desktop/vr.nix` — WiVRn, PAM limits
- `modules/gpu/nvidia.nix`

### Governance
- `modules/security/governance.nix` — 14 build-time assertions
- `modules/security/scanners.nix` — ClamAV, AIDE timers

---

## Phase 1 — Audit before install

### A. Static checks
```bash
nix flake show
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

If any fail, do **not** trust the documentation yet.

### B. Audit the audit
For each claim in `PROJECT-STATE.md`, find the code file in the code map above, open it, confirm the control is present.

## Phase 2 — Audit during install

### A. Before wiping disks
```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS,PARTLABEL,PARTUUID,UUID
blkid
bootctl status || true
```

### B. After partitioning
```bash
lsblk -f
sudo cryptsetup luksDump /dev/disk/by-partlabel/NIXCRYPT
sudo btrfs subvolume list /mnt
```

### C. Before nixos-install
```bash
findmnt -R /mnt
```

Check: `/mnt`, `/mnt/boot`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, home subvolumes all mounted.

## Phase 3 — Audit first boot

```bash
systemctl --failed
journalctl -b -p warning
findmnt -R /
id && whoami && echo "$XDG_SESSION_TYPE"
```

Verify both `player` and `ghost` can log in at SDDM. Reboot-test persistence: create a file in a persisted and non-persisted path, confirm only the intended one survives.

## Phase 4 — Secure Boot and TPM

### A. Secure Boot
```bash
bootctl status
sbctl status
mokutil --sb-state || true
```

### B. TPM
```bash
sudo systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT
```
Confirm TPM2 slot + recovery passphrase both exist.

## Phase 5 — Kernel, privilege, and service hardening

### A. Sysctl
```bash
sysctl kernel.dmesg_restrict kernel.kptr_restrict kernel.yama.ptrace_scope
sysctl kernel.unprivileged_bpf_disabled net.core.bpf_jit_harden
sysctl fs.suid_dumpable fs.protected_fifos fs.protected_regular
sysctl net.ipv6.conf.all.use_tempaddr
```
Expected: dmesg=1, kptr=2, yama=2, bpf_disabled=1, bpf_jit=2, suid_dump=0, fifos=2, regular=2, tempaddr=2.

### B. Coredump and root lock
```bash
coredumpctl list 2>&1 | head -5
grep '^root:' /etc/shadow | cut -d: -f2
```

### C. Kernel module blacklist
```bash
lsmod | grep -E 'dccp|sctp|rds|tipc|firewire'
cat /proc/cmdline | tr ' ' '\n' | grep -E 'debugfs|usbcore'
```

### D. Systemd service hardening
```bash
systemctl show flatpak-repo -p NoNewPrivileges,ProtectKernelTunables,LockPersonality
systemctl show clamav-daily-scan -p NoNewPrivileges,ProtectKernelTunables,LockPersonality
```

## Phase 6 — Networking and privacy

```bash
sudo nft list ruleset
mullvad status
resolvectl status
curl https://am.i.mullvad.net/connected
```

Disconnect VPN → verify egress fails.

## Phase 6.5 — Browser sandboxing (new)

### A. Verify sandboxed execution
```bash
# Check that safe-firefox runs in bwrap with UID 100000
ps aux | grep -E 'safe-firefox|bwrap.*firefox' | head -5
cat /proc/$(pgrep -f 'bwrap.*firefox' | head -1)/uid_map 2>/dev/null || echo "Not found"

# Verify no capability
getcap $(which safe-firefox) 2>/dev/null || echo "No capabilities (expected)"
```

### B. Verify hardened user.js
```bash
# Launch safe-firefox, check prefs are set
grep -E 'privacy.resistFingerprinting|media.peerconnection.enabled|dom.security.https_only_mode' \
  ~/.cache/safe-firefox/profile/user.js 2>/dev/null || echo "user.js in runtime profile"
```

### C. Leak tests
- WebRTC leak test: https://browserleaks.com/webrtc (should show no IP, disabled)
- Fingerprint: https://coveryourtracks.eff.org (RFP active)
- DNS leak: https://dnsleaktest.com (should show Cloudflare if DoH active)

## Phase 7 — Gaming

- Test Steam launches
- Test VR stack
- Compare FPS/frametime against baseline
- If performance drops, isolate the exact knob before keeping it

## Governance self-check
1. Is this claim listed in `PROJECT-STATE.md`?
2. Is the code file in the code map above?
3. Did I verify build/runtime, or am I trusting an inspected file?

---

## Failure modes

### Architectural
1. One install with specialisations is not strong compromise isolation
2. NVIDIA remains in both profiles for reliability
3. Mullvad behavior can change with app/nixpkgs updates
4. TPM-bound unlock can fail after measurement changes
5. tmpfs root can break packages expecting persistent root paths

### Install-time
- Wrong disk selected during wipe
- Partition labels not matching repo assumptions
- Missing subvolume mount before install

### Boot
- Secure Boot enabled before signed boot path ready
- TPM enrollment before verifying recovery passphrase
- NVIDIA/Wayland regression on driver/kernel update

### Daily profile
- Performance regression from security knobs leaking into gaming
- VR breakage from stricter kernel/module policy

### Paranoid profile
- Browser path too restrictive for usability
- Killswitch blocking expected traffic
- USB `authorized_default=2` may block external hubs/docks
- `kernel.yama.ptrace_scope=2` may break debugging tools

### Remediation matrix

| Failure class | Control | What you still must do | Audit test |
|---|---|---|---|
| Network leak | nftables killswitch + DHCP/DNS exceptions | Validate Mullvad interfaces; `mullvad lockdown-mode set on` | Disconnect VPN, verify egress fails |
| Secure Boot lockout | Staged enablement + GRUB exclusion assertion | Enroll only after first clean boot | `bootctl status`, `sbctl status` |
| TPM lockout | TPM requires systemd initrd; recovery documented | Keep recovery passphrase forever | `systemd-cryptenroll --dump` |
| Impermanence mismatch | Persist mount assertion | Reboot-test persisted paths | File survives only where intended |
| Browser sandbox bypass | `safe-firefox` wrapper | Verify wrapper path at runtime | Process tree shows bwrap/systemd-run |
| Daily gaming regression | Stock kernel + gaming sysctls (daily only) | Benchmark games/VR | Compare FPS/frametime |
| Governance drift | 14 build-time assertions | Keep `PROJECT-STATE.md` updated | Pick 3 random claims, trace to runtime |
