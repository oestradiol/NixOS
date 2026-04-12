# PROJECT STATE

## Decisions frozen
- Fresh reinstall on the NVMe target.
- One NixOS install, two boot specialisations: `daily` and `paranoid`.
- Separate users: `player` and `ghost`, selected through SDDM.
- KDE Plasma 6 on Wayland for both profiles.
- NVIDIA enabled initially in both profiles for hardware reliability.
- Windows may be removed. The separate SATA disk is intentionally left unused.
- LUKS2 + Btrfs + tmpfs root + explicit `/persist` model.
- Secure Boot + TPM2 are staged after the first known-good encrypted boot.
- Daily keeps Steam, Vesktop, VR, Signal, Bitwarden. Firefox Sync is disabled by policy (identity.fxaccounts.enabled = false) for compartmentalization.
- Paranoid forbids Steam, Vesktop and VR by default; Signal remains allowed.
- Paranoid browser path uses `safe-firefox` and separate Tor Browser/Mullvad Browser roles.
- Controllers (Bluetooth/Xbox): enabled on daily (`myOS.gaming.controllers.enable = true`), disabled on paranoid.
- Swap: zram + 8GB Btrfs swap file on `@swap` subvolume.
- AppArmor on daily: keep enabled, monitor for breakage.
- All negligible-impact hardening on daily: keep enabled, monitor post-install.
- `init_on_free=1`: paranoid-only (measurable impact).
- `nosmt=force`: paranoid-only (30-40% CPU throughput loss).
- Browser sandboxing: UID isolation (100000), bubblewrap process namespaces. Firefox hardening is arkenfox-inspired with custom preferences; not clean arkenfox alignment.
- VM isolation: implemented as knob, disabled by default, compatible with daily driver.
- Application sandboxing: replace high-risk proprietary apps with Flatpak (sandboxed) or bubblewrap wrappers (UID isolation). Signal Desktop uses Flatpak on both profiles.

## Implemented in repo
- Flake, host entrypoint, daily default profile, paranoid specialisation.
- Hardware-target mount model for the uploaded Ryzen 5 3600 + GTX 1060 system.
- tmpfs root, `/nix`, `/persist`, `/var/log`, `/swap`, split home subvolumes.
- zram (zstd 50%) + 8GB Btrfs swapfile on `@swap` subvolume (swapfile created by install script).
- Separate Home Manager configs for `player` (daily) and `ghost` (paranoid).
- Baseline hardening module with full sysctl hardening (20+ keys).
- Core dump disable, root lock, PAM su wheel-only.
- Dangerous kernel module blacklist (dccp, sctp, rds, tipc, firewire).
- USB device authorization restricted on paranoid (`myOS.security.usbRestrict`).
- `debugfs=off`, `randomize_kstack_offset=on` boot parameters.
- Browser policy module with two modes: base Firefox with arkenfox-inspired hardening (geo disabled, DoH disabled for VPN DNS, HTTPS-only, dFPI cookies, strict ETP, OCSP hard-fail) when `sandbox.browsers = false` (daily); sandboxed browser wrappers exclusively (safe-firefox with full hardened user.js, safe-tor-browser, safe-mullvad-browser) with UID isolation when `sandbox.browsers = true` (paranoid).
- Networking killswitch with DHCP/DNS exceptions for tunnel establishment.
- Agenix scaffold, impermanence module, Secure Boot + TPM merged into one staging module.
- Systemd service hardening for flatpak-repo, ClamAV, and AIDE services.
- ClamAV split scans: daily impermanence scan + weekly deep scan (comprehensive).
- AIDE weekly integrity checks with persisted database.

## Privacy and anti-fingerprinting (profile-dependent)

### Paranoid profile (maximal privacy hardening)
**Goal**: Minimize trackable hardware/software identifiers that can fingerprint the system across boots/sessions.

**Implemented mitigations**:
- **machine-id**: Whonix shared ID on paranoid (`machineIdValue = "b08dfa6083e7567a1921a715000001fb"`) - blends with Whonix users; systemd-generated stable ID on daily
- **MAC addresses**: Randomized for all interfaces via `systemd.network.links` with `MACAddressPolicy = "random"`
- **WiFi scanning**: Random MAC during network scans (`wifi.scanRandMacAddress = true`)
- **IPv6**: Privacy extensions enabled (randomized temporary addresses)
- **TCP timestamps**: Disabled (`tcp_timestamps = 0`) - prevents clock skew fingerprinting
- **Home directory**: tmpfs (wiped on boot) with selective bind-mounts only for allowlisted items
- **Root filesystem**: tmpfs (full system wipe on boot except persisted paths)

**WireGuard security note**: Uses file-based secrets (privateKeyFile/presharedKeyFile) following NixOS WireGuard best practices. Inline secrets are NOT used - they would expose keys in the nix store. All WireGuard keys must be provided via agenix or similar secrets manager.

**WireGuard endpoint DNS bootstrap**: When using hostname endpoints (e.g., us-nyc-wg-001.mullvad.net:51820), a pre-tunnel DNS exception allows DNS queries on non-WG interfaces to resolve the endpoint hostname before tunnel establishment. This is a necessary trade-off for hostname-based configs. For maximum security, use literal IP endpoints instead of hostnames to avoid this brief DNS exposure.

**Residual fingerprinting vectors** (cannot fully mitigate without breakage):
- **DMI/SMBIOS data** (`/sys/class/dmi/id/`): Hardware model, serial numbers - world-readable, required by kernel
- **CPU model/features**: Exposed via `/proc/cpuinfo` - required for userspace operation
- **TPM EK** (if enrolled): Hardware-bound persistent key - don't enroll TPM if you want to avoid this
- **Disk serial numbers**: Available via `smartctl`, `hdparm` - requires root, but persistent
- **USB device topology**: Persistent port/device relationships

### Daily profile (operational stability prioritized)
- **machine-id**: Systemd-generated stable ID (`persistMachineId = true`) - required for D-Bus, Steam, systemd state
- **MAC addresses**: Stable per network (`MACAddressPolicy = "stable"`) - prevents WiFi captive portal re-auth issues
- **WiFi scanning**: Random MAC during scans only
- **IPv6**: Privacy extensions enabled (standard privacy)
- **TCP timestamps**: Enabled (needed for some gaming/networking optimizations)
- **Home directory**: Fully persistent Btrfs subvolume

## Security monitoring exclusions (documented for awareness)

**ClamAV scan targets**: `/home/player`, `/home/ghost`, `/persist`, `/persist/home/ghost`, `/var/lib`, `/var/log`, `/tmp`, `/var/tmp`, `/boot`

**ClamAV exclusions** (via `--exclude-dir` flags in daily/impermanence and deep scans):
- `/persist/etc/ssh` — SSH keys (high-churn, sensitive)
- `/home/player/.*\.steam` — Steam runtime files (regex pattern)
- `/home/player/.local/share/Steam` — Steam data (daily scan excludes entire dir)
- `/home/player/.local/share/Steam/steamapps` — Game files (deep scan only)
- `/home/player/.var/app` — Flatpak application data (sandboxed, trusted platform)
- `/var/log/journal` — Binary journal logs (noisy, not meaningful to scan)

**AIDE exclusions** (via `!` directives in aide.conf):
- `/persist/var/lib/aide` — AIDE's own database
- `/home/player/.local/share/Steam` — Steam runtime files
- `/home/player/.steam` — Steam configuration
- `/var/lib/systemd` — Volatile service state
- `/var/log/journal` — Volatile binary logs

**Design note**: Both daily and paranoid persisted directories are scanned by ClamAV and monitored by AIDE. Profile separation isolates runtime environments, not scan coverage — malware in `/persist/home/ghost` would still be detected from the daily profile.

**Trust note**: Steam games, Flatpak user data, and Nix store packages are intentionally NOT scanned:
- **Steam store**: Games cryptographically signed, delivered via TLS; Steam runtime excluded from scans
- **Flathub apps**: User app data (`~/.var/app`) excluded; system Flatpak content under `/var/lib/flatpak` is scanned as part of `/var/lib`
- **NixOS cache**: Cryptographically hashed, bit-reproducible builds

Users should not sideload untrusted binaries into these directories. The Nix store (`/nix/store`) is read-only, hash-verified, and excluded from scans by design.

- 30 governance assertions (8 use list-membership checks; remainder are boolean/option existence assertions).
- **Build-time checks**: `flake.nix` includes `checks.x86_64-linux` with nixos-config and paranoid-config evaluation tests; run via `nix flake check`.
- **Audit script**: `scripts/audit-tutorial.sh` runs static checks; failures now propagate (removed `|| true` masking).
- **Explicit unfree package allowlist** (nvidia-x11, nvidia-settings, steam, gamescope) - no blanket allowUnfree.
- **All hardening knobs configurable via `myOS.security.*` options** — profiles set presets, users can override per-knob.
- **Module structure minimized**: `core/` (4 files), `security/` (11 files), `desktop/` (5 files), `home/` (3 files), `gpu/` (2 files).
- **Docs minimized**: 8 surviving docs (down from 28), single front-door README.
- All hardening topics tracked in `docs/audit/SOURCE-TOPIC-LEDGER.md`.

## Configurable myOS.security options
All key hardening knobs are tunable per-profile without code changes:
- `kernelHardening.{initOnAlloc, initOnFree, slabNomerge, pageAllocShuffle, moduleBlacklist, pti, vsyscallNone, oopsPanic, moduleSigEnforce, disableIcmpEcho}`
- `apparmor`, `auditd`, `lockRoot`, `usbRestrict`, `sandbox.vms`, `sandbox.apps`
- `disableSMT`, `sandbox.browsers`, `hardenedMemory.enable`
- `ptraceScope` (kernel.yama.ptrace_scope: 1 for EAC compatibility, 2 for hardening)
- `swappiness` (vm.swappiness: lower values for gaming, higher for systems with limited RAM)
- `secureBoot.enable`, `tpm.enable`, `impermanence.enable`, `agenix.enable`
- `wireguardMullvad.enable` — `true` = self-owned WireGuard (paranoid), `false` = Mullvad app (daily, default)

## Gaming knobs
- `myOS.gaming.controllers.enable` — Bluetooth/Xbox controller support (xpadneo, udev rules, blueman)
- `myOS.gaming.sysctls` — SteamOS-aligned scheduler tuning and RT scheduling (default: true)

## Browser security architecture (research-grounded)
### Sandboxing (bubblewrap)
- UID namespace: browser runs as UID 100000 (unmapped on host)
- IPC/PID/UTS namespaces for process isolation
- Minimal filesystem: ro-bind system dirs, tmpfs for home/runtime
- GPU/Wayland/PipeWire socket passthrough (read-only)
- No capabilities (`--cap-drop ALL`)
- Die-with-parent: auto-cleanup when launcher exits
- **D-Bus filtering**: When enabled (sandbox.dbusFilter = true), full /run/user bind is REMOVED to prevent real bus access
  - Only specific proxy sockets are bound (xdg-dbus-proxy filtered)
  - This is ADVISORY filtering — motivated attackers may still find IPC bypass paths
  - When disabled: full /run/user bind for compatibility (real bus exposed)

### Firefox hardening (arkenfox-grounded user.js)
- 70+ hardened prefs covering: startup, geolocation, telemetry (Normandy/Shield), safe browsing, implicit outbound blocking, DoH disabled (VPN DNS only), HTTPS-only mode, SSL/TLS hardening (safe negotiation, 0-RTT disabled, OCSP hard-fail), HPKP/CRLite, referer trimming, container tabs, WebRTC disabled, dFPI, RFP (resist fingerprinting), shutdown sanitizing
- Auto-clears cookies/storage/cache/formdata on exit
- WebRTC: disabled on paranoid (prevents IP leak), enabled on daily (gaming/video calls)
- Container tabs enabled for site isolation

## Application sandboxing architecture
### Flatpak (daily + paranoid profiles)
- High-risk proprietary apps use Flatpak where available; otherwise bubblewrap
- Flatpak provides namespace isolation, capability dropping, read-only filesystem by default
- Flathub remote configured automatically via systemd service (flatpak-repo)
- App data persistence scaffolded for: Signal, Spotify, Bitwarden, Vesktop, Obsidian
- Packages installed manually after first boot (see POST-STABILITY.md)
- App data persisted via impermanence: `~/.var/app/com.example.App`

### Bubblewrap wrappers (non-Flatpak apps like VRCX, Windsurf)
- UID isolation (100000:100000 unmapped from host)
- Process namespace isolation (IPC, PID, UTS) — **Network namespace is NOT isolated**
- Minimal filesystem access (ro-bind system dirs)
- GPU/Wayland/PipeWire socket passthrough (read-only)
- Input device passthrough for keyboard/mouse
- Capability dropping (`--cap-drop ALL`)
- Die-with-parent for auto-cleanup
- Apps wrapped: VRCX, Windsurf (daily)
- **D-Bus filtering**: When enabled (sandbox.dbusFilter = true), full /run/user bind is REMOVED to prevent real bus access
  - Only specific proxy sockets are bound (xdg-dbus-proxy filtered)
  - This is ADVISORY filtering — motivated attackers may still find IPC bypass paths
  - When disabled: full /run/user bind for compatibility (real bus exposed)

## VM isolation layer (strongest practical sandbox)
- KVM/QEMU with hardware virtualization (AMD-V/VT-x)
- Auto-detects AMD vs Intel KVM modules
- IOMMU passthrough mode (`iommu=pt`, `amd_iommu=on`)
- TPM emulation for VMs (swtpm)
- QEMU hardening: seccomp sandbox, SPICE/VNC TLS
- virt-manager GUI enabled when knob active
- Users `player` and `ghost` added to `libvirtd` group
- **Knob**: `myOS.security.sandbox.vms` (default: false)
- **Compatible with daily driver**, significant resource overhead when enabled

## Kernel hardening knobs (Madaidan-research grounded)
All tunable via `myOS.security.kernelHardening.*`:

**Enabled by default (daily):**
- `initOnAlloc` — zero pages on allocation (init_on_alloc=1)
- `slabNomerge` — prevent slab cache merging
- `moduleBlacklist` — blacklist dangerous kernel modules (dccp, sctp, rds, tipc, firewire)
- `pti=on` — Kernel Page Table Isolation (Meltdown mitigation)
- `vsyscall=none` — disable vsyscalls (ROP prevention)
- `pageAllocShuffle` — randomize page allocator freelists (<1% impact, no gaming breakage)

**Enabled on paranoid (explicit with mkForce):**
- `initOnFree` — zero pages on free (1-7% overhead)
- `pageAllocShuffle` — randomize page allocator freelists
- `oopsPanic` — panic on kernel oops (prevents exploit continuation)
- `moduleSigEnforce` — only load signed kernel modules
- `disableIcmpEcho` — ignore ping requests (network enumeration prevention)

**Intentionally disabled (deferred):**
- `hardenedMemory` — Graphene hardened allocator (stability risk, enable only after post-install testing)

## Needs live validation
- Real destructive install on the NVMe.
- Actual boot success on the target machine.
- SDDM user separation flow.
- Mullvad killswitch behavior, WebRTC/DNS leak behavior, Tor Browser role separation.
- Secure Boot key enrollment and actual measured boot path.
- TPM2 enrollment and recovery-passphrase fallback.
- Steam/VR/gaming performance and compatibility on the daily profile.
- AIDE database initialization and usefulness on the rebuilt host.

## Not yet implemented
- Remote wipe / dead-man switch integration.
- Full virtualization split (optional later wave).
- Full `graphene-hardened` allocator rollout (keep off until post-install testing).
- Line-by-line nix-mineral diff.
- Repo-wide hardened compilation flags policy.
- Memory-safe-language enforcement policy.
- Dedicated entropy-hardening component.
- Root-editing discipline enforcement in code (documented only).
- NTS time sync replacement.
- Broad SUID/capabilities pruning program.
- Wayland-only display manager (three-phase roadmap):
  - Phase 1 (current): X11 server runs for SDDM/NVIDIA compatibility, user sessions are Wayland-only, X apps use XWayland automatically
  - Phase 2 (post-stability): Evaluate greetd + tuigreet for Wayland-native DM (experimental, may break NVIDIA)
  - Phase 3 (October 2026): Plasma 6.8 Wayland-exclusive release (drops X11 session support entirely)

## Rejected or intentionally deferred
- Treating boot specialisations as strong compromise isolation.
- Turning on Secure Boot before the first ordinary encrypted boot works.
- Using TPM as the only disk-unlock path.
- Forcing the paranoid profile to drop NVIDIA before the system is stable.
- Making virtualization a required part of the first implementation wave.
- Choosing SELinux for wave one; AppArmor is the selected MAC path.
- Choosing Firejail for wave one; Flatpak and bubblewrap wrappers are the selected path.
- Choosing `doas`/`run0` for wave one; sudo remains in place for now.
- Choosing `disko` for wave one; the install path remains manual/scripted.

## Trust model

### Profile Policy Verification Matrix

| Policy | Daily | Paranoid | Status |
|--------|-------|----------|--------|
| **Gaming/Steam** | Enabled (`steam.enable = true`) | Disabled (`steam.enable = lib.mkForce false`) | PASS |
| **VR/WiVRn** | Enabled (`services.wivrn.enable = true`) | Disabled (`services.wivrn.enable = lib.mkForce false`) | PASS |
| **Controllers** | Enabled (`controllers.enable = true`) | Disabled (`controllers.enable = lib.mkForce false`) | PASS |
| **Gamescope** | Enabled | Disabled (`programs.gamescope.enable = lib.mkForce false`) | PASS |
| **Gamemode** | Enabled | Disabled (`programs.gamemode.enable = lib.mkForce false`) | PASS |
| **Browser** | Base Firefox (`sandbox.browsers = false`) | Sandboxed only (`sandbox.browsers = lib.mkForce true`) | PASS |
| **VPN** | Mullvad app (`wireguardMullvad.enable = false`, default) | Self-owned WireGuard (`wireguardMullvad.enable = lib.mkForce true`) | PASS |
| **SMT/Hyperthreading** | Enabled (`disableSMT = false`) | Disabled (`disableSMT = lib.mkForce true`) | PASS |
| **USB restriction** | Disabled (`usbRestrict = false`) | Enabled (`usbRestrict = lib.mkForce true`) | PASS |
| **Audit logging** | Disabled (`auditd = false`) | Enabled (`auditd = lib.mkForce true`) | PASS |
| **VM isolation** | Disabled (`sandbox.vms = false`) | Enabled (`sandbox.vms = lib.mkForce true`) | PASS |
| **Home persistence** | Full Btrfs subvolume | Selective tmpfs + allowlist | PASS |
| **Machine-id** | Systemd-generated stable (`persistMachineId = true`) | Whonix shared ID (`machineIdValue = "b08dfa6083e7567a1921a715000001fb"`) | PASS |
| **MAC addresses** | Stable per network | Random per device appearance (typically at boot) | PASS |
| **ptrace scope** | 1 (EAC compatible) | 2 (strictest) | PASS |
| **init_on_free** | Disabled (performance) | Enabled (`initOnFree = lib.mkForce true`) | PASS |
| **oops_panic** | Disabled (stability) | Enabled (`oopsPanic = lib.mkForce true`) | PASS |
| **Memory allocator** | Disabled | Deferred (test post-install) | PASS |
| **AIDE/ClamAV** | Enabled | Enabled (both profiles) | PASS |
| **Root lock** | Enabled (`lockRoot = true`) | Enabled (`lockRoot = lib.mkForce true`) | PASS |
| **AppArmor** | Enabled (`apparmor = true`) | Enabled (`apparmor = lib.mkForce true`) | PASS |

### Daily
- Broad desktop convenience: gaming, VR, sync, messenger sprawl allowed.
- **VPN**: Mullvad app for convenience (key rotation, multihop, GUI controls). No strict killswitch required.
- All proprietary apps sandboxed via Flatpak or bubblewrap wrappers.
- **Privacy**: MAC stable per network; machine-id is systemd-generated stable unique ID.

### Paranoid
- Separate user `ghost`, stricter browser policy, Signal only.
- Vesktop, Steam, VR disabled by policy.
- **VPN**: Self-owned WireGuard to Mullvad servers. No Mullvad app. NixOS owns tunnel state AND firewall policy (single source of truth). Deterministic killswitch generated from WireGuard config.
- Lower persistence footprint (tmpfs home, selective allowlist).
- Signal Desktop sandboxed via Flatpak.
- **Privacy**: Randomized MAC per device appearance (typically at boot); machine-id is Whonix shared ID (blends with Whonix users); TCP timestamps disabled.

### Isolation truth
- Boot specialisations separate behavior, not compromise.
- Separate users reduce accidental cross-contamination.
- tmpfs root reduces simple persistence.
- Flatpak + bubblewrap + systemd hardening reduce app blast radius.
- All high-risk apps (Electron, proprietary) sandboxed with UID isolation.
- Real containment still requires separate hardware, full VM, or Qubes-level isolation.

### MONITOR: Ongoing tracking required
- **Tor/Mullvad D-Bus namespace**: https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050
  - Currently using `org.mozilla.firefox.*`; may change to `org.torproject` or `net.mullvad`
  - Check on browser updates; update `browser.nix` if namespace changes
- **KDE Plasma 6.8+ X11 deprecation**: Plasma 6.8 drops X11 session support entirely
  - Test all apps under XWayland compatibility before upgrade
  - Verify no hard X dependencies remain (xeyes, xev, etc.)
  - Plan transition to X-disabled configuration (remove services.xserver.enable)
- **NVIDIA legacy_580 driver**: Track https://github.com/NixOS/nixpkgs/issues/503740
  - GTX 1060 (Pascal) should use `legacy_580`; currently on `production` as fallback
  - Migrate when nixpkgs exposes `legacy_580` properly

## Audit summary

# AUDIT

## Final pass summary
This repository is materially stronger than the original gaming-first unstable-only config.

### What changed structurally
- moved from one monolithic host config to one host with two boot specialisations
- added separate SDDM users for daily and paranoid use
- replaced current ext4 mental model with a hardware-adapted reinstall target
- added tmpfs root + impermanence model
- staged Secure Boot and TPM instead of enabling them prematurely
- added governed docs and audit surfaces

### What is fully implemented in repo form
- flake restructure with anonymous user identities (`player`/`ghost`)
- host entrypoint with system-wide Secure Boot/TPM staging
- target storage model (LUKS2 + Btrfs + tmpfs root)
- daily/paranoid profile split with governance assertions
- user split with locked root, wheel-restricted su
- full sysctl hardening baseline (20+ keys)
- kernel module blacklist, coredump disable, debugfs off
- USB authorization restricted on paranoid
- IPv6 privacy extensions
- VPN: Mullvad app for daily; self-owned WireGuard for paranoid (single-source-of-truth firewall)
- browser policy split; plain Firefox removed from paranoid
- systemd service hardening for flatpak, ClamAV, AIDE
- install/test/recovery docs

### What remains manual by nature
- destructive repartition/install
- real account secrets
- Mullvad login/account state
- Secure Boot key enrollment in firmware
- TPM enrollment
- actual leak tests and performance comparison

### Self-critique
- `safe-firefox` is a practical wrapper, not a proof of maximal browser isolation
- Mullvad lockdown nftables may need local adjustment after first real connection test
- NVIDIA in paranoid is a compatibility compromise
- hardened allocator remains intentionally disabled until the rest is debugged
- NVIDIA package: temporarily using `production` branch instead of ideal `legacy_580` due to nixpkgs#503740
- VPN architecture: paranoid uses self-owned WireGuard (Mullvad as provider only, NixOS as authority)
