# PRE-INSTALL

Check and verify everything **before** running the install.

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
- `modules/home/player.nix`, `modules/home/ghost.nix`
- `profiles/daily.nix`, `profiles/paranoid.nix`

### Storage / persistence / secrets
- `modules/security/impermanence.nix`
- `modules/security/secrets.nix`

### Networking / browser / privacy
- `modules/security/networking.nix` — killswitch, nftables
- `modules/security/browser.nix` — Firefox policies or sandboxed browser wrappers (UID 100000, bubblewrap)
  - When `sandboxedBrowsers.enable = false` (daily): Base Firefox with 60+ hardening prefs (all telemetry disabled, safe browsing local-only, prefetch blocked, HTTPS-only, dFPI, ETP strict, OCSP hard-fail, container tabs, shutdown sanitizing, FPP fingerprinting protection per arkenfox v140+)
  - When `sandboxedBrowsers.enable = true` (paranoid): Base Firefox disabled, only sandboxed wrappers available (safe-firefox with full hardened user.js including RFP, safe-tor-browser, safe-mullvad-browser)
- `modules/security/flatpak.nix` — flatpak + xdg portals
- `modules/security/sandboxed-apps.nix` — bubblewrap wrappers for non-Flatpak apps (VRCX, Windsurf)
- `modules/home/ghost.nix` — Signal (Flatpak) only; browsers via system wrappers

### Gaming
- `modules/desktop/gaming.nix` — Steam, gamescope, gamemode, controllers knob
- `modules/desktop/vr.nix` — WiVRn, PAM limits
- `modules/gpu/nvidia.nix`

### VM isolation
- `modules/security/vm-isolation.nix` — KVM/QEMU, virt-manager, AMD/Intel IOMMU

### Governance
- `modules/security/governance.nix` — 27 build-time assertions
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

---

## Phase 2 — Audit during install

### A. Before wiping disks

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS,PARTLABEL,PARTUUID,UUID
blkid
bootctl status || true
```

**Verify**: You are targeting the correct disk. SATA disk is untouched.

### B. After partitioning

```bash
lsblk -f
sudo cryptsetup luksDump /dev/disk/by-partlabel/NIXCRYPT
sudo btrfs subvolume list /mnt
```

**Verify**: LUKS2 header present, Btrfs subvolumes created correctly.

### C. Before nixos-install

```bash
findmnt -R /mnt
```

Check: `/mnt`, `/mnt/boot`, `/mnt/nix`, `/mnt/persist`, `/mnt/var/log`, home subvolumes all mounted.

**If mount issues occur**: See [`RECOVERY.md`](./RECOVERY.md) boot recovery section.

---

## Failure modes (pre-install)

| Failure | Cause | Prevention |
|---------|-------|------------|
| Wrong disk selected during wipe | Inattentive `lsblk` | Double-check PARTLABELs before any destructive command |
| Partition labels not matching repo assumptions | Manual partitioning | Use `scripts/install-nvme-rebuild.sh` or match its layout exactly |
| Missing subvolume mount before install | Forgot `mount -o subvol=@nix` | Run `findmnt -R /mnt` and verify all subvolumes |
| Secure Boot enabled before signed boot path ready | Firmware settings | Keep Secure Boot disabled for first install |
| Missing recovery passphrase | Did not record it | Write LUKS passphrase down before enrollment |

---

## Phase 3 — Security audit checklist (VERIFY BEFORE TRUST)

**Assumption: Everything is hallucinated until proven otherwise.**

For each security claim, verify the code matches the documentation.

### Browser sandboxing

| Claim | Verification | Status |
|-------|--------------|--------|
| UID isolation (100000:100000) | `modules/security/browser.nix:28` has `--uid 100000 --gid 100000` | ✅ VERIFIED |
| **NO network namespace** | Code has `--unshare-user/ipc/pid/uts` but **NOT** `--unshare-net` | ✅ CORRECT (browsers need host VPN/Tor) |
| GPU passthrough | `--dev-bind /dev/dri` exposes GPU attack surface | ⚠️ ACKNOWLEDGED |
| Process namespace | `--unshare-pid` present | ✅ VERIFIED |

**Action**: Confirm docs don't claim network isolation for browsers.

### Networking / killswitch

| Claim | Verification | Status |
|-------|--------------|--------|
| nftables lockdown | `modules/security/networking.nix:30-65` | ✅ VERIFIED |
| VPN interface whitelist | `wg-mullvad`, `tun0`, `tun1` accepted | ✅ VERIFIED |
| **Mullvad IP constraint** | Lines 54-61 constrain UDP 51820 and TCP 443/1401 to specific Mullvad IPs | ✅ VERIFIED |
| Firewall disabled in lockdown | `networking.firewall.enable = !config.myOS.security.mullvad.lockdown` | ✅ VERIFIED |

**Mullvad infrastructure IPs (VERIFY CURRENT AT https://mullvad.net/en/servers BEFORE INSTALL):**
```
WireGuard relays: 185.65.134.0/24, 185.65.135.0/24, 193.138.219.0/24
API/Bridge: 185.65.134.66, 185.65.135.1, 193.138.219.228
```
**CRITICAL**: If these IPs have rotated, the killswitch will block Mullvad connection. Verify current IPs and update `modules/security/networking.nix` before install.

### Base security

| Claim | Verification | Status |
|-------|--------------|--------|
| 20+ hardened sysctls | `modules/security/base.nix:22-48` | ✅ VERIFIED |
| Kernel module blacklist | `base.nix:52-55`: dccp, sctp, rds, tipc, firewire | ✅ VERIFIED |
| Coredump disabled | `base.nix:12-15`: `Storage=none` | ✅ VERIFIED |
| Root locked | `base.nix:18`: `hashedPassword = "!"` when lockRoot | ✅ VERIFIED |
| su wheel-only | `base.nix:19`: `requireWheel = sec.lockRoot` | ✅ VERIFIED |

### Governance assertions

| Claim | Verification | Status |
|-------|--------------|--------|
| 27 assertions | `modules/security/governance.nix` lines 7-119 | ✅ VERIFIED |
| Paranoid requires sandboxed browsers | Lines 17-18 | ✅ VERIFIED |
| Paranoid requires Mullvad lockdown | Lines 21-26 | ✅ VERIFIED |
| Paranoid ghost not in wheel | Lines 61-62 | ✅ VERIFIED |
| Daily no hardened memory | Lines 105-106 | ✅ VERIFIED |

### Scanners

| Claim | Verification | Status |
|-------|--------------|--------|
| Daily shallow scan (daily) | `scanners.nix:47-73` | ✅ VERIFIED |
| Deep scan (weekly) | `scanners.nix:78-103` | ✅ VERIFIED |
| AIDE persistence | `impermanence.nix:15`: `/var/lib/aide` persisted | ✅ VERIFIED |
| ClamAV signature updates | `scanners.nix:106-110`: `services.clamav.updater` | ✅ VERIFIED |

### Users / first-boot

| Claim | Verification | Status |
|-------|--------------|--------|
| No initial password | `users.nix`: No `initialHashedPassword` or `hashedPassword` set | ✅ VERIFIED |
| Password setup BEFORE first boot | Documented in INSTALL-GUIDE.md Phase 4: set via chroot or `initialPassword` | ✅ VERIFIED |

**CRITICAL**: NixOS users WITHOUT a password **CANNOT** log in via password-based mechanisms (TTY, SDDM).
See: https://nixos.org/manual/nixos/stable/options#opt-users.mutableUsers

### Secure Boot / TPM

| Claim | Verification | Status |
|-------|--------------|--------|
| Lanzaboote integration | `secure-boot.nix:6-9` | ✅ VERIFIED |
| TPM requires systemd initrd | `secure-boot.nix:13-16` | ✅ VERIFIED |
| Staged (disabled by default) | `hosts/nixos/default.nix:38-39` | ✅ VERIFIED |

---

## Governance self-check

1. Is this claim listed in `PROJECT-STATE.md`?
2. Is the code file in the code map above?
3. Did I verify build/runtime, or am I trusting an inspected file?

---

**Next**: After install completes, proceed to [`TEST-PLAN.md`](./TEST-PLAN.md) for runtime verification.
