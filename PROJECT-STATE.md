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
- Daily keeps Steam, Vesktop, Firefox Sync, VR, Telegram, Matrix, Signal, Bitwarden.
- Paranoid forbids Firefox Sync, Steam, Vesktop, Telegram, Matrix by default; Signal remains allowed.
- Paranoid browser path uses `safe-firefox` and separate Tor Browser/Mullvad Browser roles.
- Controllers (Bluetooth/Xbox): keep disabled, enable manually later.
- Swap: zram + 8GB Btrfs swap file on `@swap` subvolume.
- AppArmor on daily: keep enabled, monitor for breakage.
- All negligible-impact hardening on daily: keep enabled, monitor post-install.
- `init_on_free=1` and `page_alloc.shuffle=1`: paranoid-only (measurable impact).
- `nosmt=force`: paranoid-only (30-40% CPU throughput loss).
- Browser sandboxing: national-level with UID isolation (100000), bubblewrap namespaces, arkenfox-grounded user.js.
- VM isolation: implemented as knob, disabled by default, compatible with daily driver.
- Application sandboxing: replace high-risk proprietary apps with Flatpak (sandboxed) or bubblewrap wrappers (UID isolation). Signal Desktop uses Flatpak on both profiles.

## Implemented in repo
- Flake, host entrypoint, daily default profile, paranoid specialisation.
- Hardware-target mount model for the uploaded Ryzen 5 3600 + GTX 1060 system.
- tmpfs root, `/nix`, `/persist`, `/var/log`, `/swap`, split home subvolumes.
- zram (zstd 50%) + 8GB Btrfs swap file fallback on `@swap` subvolume.
- Separate Home Manager configs for `player` (daily) and `ghost` (paranoid).
- Baseline hardening module with full sysctl hardening (20+ keys).
- Core dump disable, root lock, PAM su wheel-only.
- Dangerous kernel module blacklist (dccp, sctp, rds, tipc, firewire).
- USB device authorization restricted on paranoid (`myOS.security.usbRestrict`).
- `debugfs=off`, `randomize_kstack_offset=on` boot parameters.
- Browser policy module with two modes: base Firefox with moderate arkenfox-style hardening (geo disabled, DoH, HTTPS-only, dFPI cookies, strict ETP, OCSP hard-fail) when `sandboxedBrowsers.enable = false` (daily); sandboxed browser wrappers exclusively (safe-firefox with full hardened user.js, safe-tor-browser, safe-mullvad-browser) with UID isolation when `sandboxedBrowsers.enable = true` (paranoid).
- Networking killswitch with DHCP/DNS exceptions for tunnel establishment.
- Agenix scaffold, impermanence module, Secure Boot + TPM merged into one staging module.
- Systemd service hardening for flatpak-repo, ClamAV, and AIDE services.
- Daily-only scanner timers for ClamAV and AIDE checks.
- 27 governance assertions (8 use list-membership checks; remainder are boolean/option existence assertions).
- **Explicit unfree package allowlist** (nvidia-x11, nvidia-settings, steam, gamescope) - no blanket allowUnfree.
- **All hardening knobs configurable via `myOS.security.*` options** — profiles set presets, users can override per-knob.
- **Module structure minimized**: `core/` (4 files), `security/` (11 files), `desktop/` (5 files), `home/` (3 files), `gpu/` (2 files).
- **Docs minimized**: 8 surviving docs (down from 28), single front-door README.
- All hardening topics tracked in `docs/audit/SOURCE-TOPIC-LEDGER.md`.

## Configurable myOS.security options
All key hardening knobs are tunable per-profile without code changes:
- `kernelHardening.{initOnAlloc, initOnFree, slabNomerge, pageAllocShuffle, moduleBlacklist, pti, vsyscallNone, oopsPanic, moduleSigEnforce, disableIcmpEcho}`
- `apparmor`, `auditd`, `lockRoot`, `usbRestrict`, `vmIsolation.enable`, `sandboxedApps.enable`
- `disableSMT`, `sandboxedBrowsers.enable`, `hardenedMemory.enable`
- `ptraceScope` (kernel.yama.ptrace_scope: 1 for EAC compatibility, 2 for hardening)
- `swappiness` (vm.swappiness: lower values for gaming, higher for systems with limited RAM)
- `secureBoot.enable`, `tpm.enable`, `impermanence.enable`, `agenix.enable`
- `mullvad.{enable, lockdown}`

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

### Firefox hardening (arkenfox-grounded user.js)
- 70+ hardened prefs covering: startup, geolocation, telemetry (Normandy/Shield), safe browsing, implicit outbound blocking, DNS/DoH, HTTPS-only mode, SSL/TLS hardening (safe negotiation, 0-RTT disabled, OCSP hard-fail), HPKP/CRLite, referer trimming, container tabs, WebRTC disabled, dFPI, RFP (resist fingerprinting), shutdown sanitizing
- Auto-clears cookies/storage/cache/formdata on exit
- WebRTC disabled (prevents IP leak)
- Container tabs enabled for site isolation

## Application sandboxing architecture
### Flatpak (daily + paranoid profiles)
- All high-risk proprietary apps replaced with Flatpak versions where available
- Flatpak provides namespace isolation, capability dropping, read-only filesystem by default
- Apps installed: Signal, Spotify, Bitwarden, Vesktop, Obsidian, Telegram, Element
- Flathub remote configured automatically via systemd service (flatpak-repo)
- Packages installed manually after first boot (see POST-INSTALL.md)
- App data persisted via impermanence: `~/.var/app/com.example.App`

### Bubblewrap wrappers (non-Flatpak apps)
- UID isolation (100000:100000 unmapped from host)
- Network namespace isolation
- Minimal filesystem access (ro-bind system dirs)
- GPU/Wayland/PipeWire socket passthrough (read-only)
- Input device passthrough for keyboard/mouse
- Capability dropping (`--cap-drop ALL`)
- Die-with-parent for auto-cleanup
- Apps wrapped: VRCX, Windsurf (daily)

## VM isolation layer (strongest practical sandbox)
- KVM/QEMU with hardware virtualization (AMD-V/VT-x)
- Auto-detects AMD vs Intel KVM modules
- IOMMU passthrough mode (`iommu=pt`, `amd_iommu=on`)
- TPM emulation for VMs (swtpm)
- QEMU hardening: seccomp sandbox, SPICE/VNC TLS
- virt-manager GUI enabled when knob active
- Users `player` and `ghost` added to `libvirtd` group
- **Knob**: `myOS.security.vmIsolation.enable` (default: false)
- **Compatible with daily driver**, significant resource overhead when enabled

## Kernel hardening knobs (Madaidan-research grounded)
All tunable via `myOS.security.kernelHardening.*`:

**Enabled by default (daily):**
- `initOnAlloc` — zero pages on allocation (init_on_alloc=1)
- `slabNomerge` — prevent slab cache merging
- `moduleBlacklist` — blacklist dangerous kernel modules (dccp, sctp, rds, tipc, firewire)
- `pti=on` — Kernel Page Table Isolation (Meltdown mitigation)
- `vsyscall=none` — disable vsyscalls (ROP prevention)

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
### Daily
- Broad desktop convenience: gaming, VR, sync, messenger sprawl allowed.
- No hard VPN killswitch required.
- All proprietary apps sandboxed via Flatpak or bubblewrap wrappers.

### Paranoid
- Separate user `ghost`, stricter browser policy, Signal only.
- Vesktop, Telegram, Matrix, Steam, VR disabled by policy.
- Mullvad intended as always-on; lockdown networking.
- Lower persistence footprint.
- Signal Desktop sandboxed via Flatpak.

### Isolation truth
- Boot specialisations separate behavior, not compromise.
- Separate users reduce accidental cross-contamination.
- tmpfs root reduces simple persistence.
- Flatpak + bubblewrap + systemd hardening reduce app blast radius.
- All high-risk apps (Electron, proprietary) sandboxed with UID isolation.
- Real containment still requires separate hardware, full VM, or Qubes-level isolation.

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
- Mullvad service path with defense-in-depth nftables killswitch
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
