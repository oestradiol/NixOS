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
- Daily keeps Steam, Discord, Firefox Sync, VR, Telegram, Matrix, Signal, KeePassXC.
- Paranoid forbids Firefox Sync, Steam, Discord, Telegram, Matrix by default; Signal remains allowed.
- Paranoid browser path uses `safe-firefox` and separate Tor Browser/Mullvad Browser roles.

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
- Browser policy module with `safe-firefox` wrapper; plain Firefox removed from paranoid.
- Networking killswitch with DHCP/DNS exceptions for tunnel establishment.
- Agenix scaffold, impermanence module, Secure Boot + TPM merged into one staging module.
- Systemd service hardening for flatpak-repo, ClamAV, and AIDE services.
- Daily-only scanner timers for ClamAV and AIDE checks.
- 14 governance assertions with correct list-membership checks.
- **All hardening knobs configurable via `myOS.security.*` options** — profiles set presets, users can override per-knob.
- **Module structure minimized**: `core/` (4 files), `security/` (9 files), `desktop/` (5 files), `home/` (3 files), `gpu/` (3 files).
- **Docs minimized**: 11 surviving docs (down from 28), single front-door README, merged AUDIT.md.
- All hardening topics tracked in `docs/audit/SOURCE-TOPIC-LEDGER.md`.

## Configurable myOS.security options
All key hardening knobs are now tunable per-profile without code changes:
- `kernelHardening.{initOnAlloc, initOnFree, slabNomerge, pageAllocShuffle, moduleBlacklist}`
- `apparmor`, `auditd`, `lockRoot`, `usbRestrict`, `gamingSysctls`
- `disableSMT`, `browserLockdown.enable`, `hardenedMemory.enable`
- `secureBoot.enable`, `tpm.enable`, `impermanence.enable`, `agenix.enable`
- `mullvad.{enable, lockdown}`

## User decisions (this session)
- Controllers (Bluetooth/Xbox): keep disabled, enable manually later.
- Swap: zram + 8GB Btrfs swap file on `@swap` subvolume.
- AppArmor on daily: keep enabled, monitor for breakage.
- All negligible-impact hardening on daily: keep enabled, monitor post-install.
- `init_on_free=1` and `page_alloc.shuffle=1`: paranoid-only (measurable impact).
- `nosmt=force`: paranoid-only (30-40% CPU throughput loss).

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
- Malware Knowledge chat reconciliation (source content still absent).
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

## Rejected or intentionally deferred
- Treating boot specialisations as strong compromise isolation.
- Turning on Secure Boot before the first ordinary encrypted boot works.
- Using TPM as the only disk-unlock path.
- Forcing the paranoid profile to drop NVIDIA before the system is stable.
- Making virtualization a required part of the first implementation wave.
- Choosing SELinux for wave one; AppArmor is the selected MAC path.
- Choosing Firejail for wave one; Flatpak and bubblewrap wrappers are the selected path.
- Choosing `doas`/`run0` for wave one; sudo remains in place for now.
- Choosing `disco` for wave one; the install path remains manual/scripted.

## Trust model
### Daily
- Broad desktop convenience: gaming, VR, sync, messenger sprawl allowed.
- No hard VPN killswitch required.

### Paranoid
- Separate user `ghost`, stricter browser policy, Signal only.
- Discord, Telegram, Matrix, Steam, VR disabled by policy.
- Mullvad intended as always-on; lockdown networking.
- Lower persistence footprint.

### Isolation truth
- Boot specialisations separate behavior, not compromise.
- Separate users reduce accidental cross-contamination.
- tmpfs root reduces simple persistence.
- Flatpak + bubblewrap + systemd hardening reduce app blast radius.
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
