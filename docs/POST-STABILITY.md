# POST-STABILITY

Configuration and hardening steps to perform **after** the system is stable and all [`TEST-PLAN.md`](./TEST-PLAN.md) checks pass.

For recovery procedures if issues occur, see [`RECOVERY.md`](./RECOVERY.md).

---

## 1. Passwords and users
- set passwords for `player` and `ghost`
- decide whether `ghost` should remain non-wheel

## 2. Update the first generation cleanly
- `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
- reboot once more

## 3. Enable paranoid specialisation
- after rebuild, a `paranoid` specialisation should exist in the boot menu
- boot it once and verify it reaches SDDM

## 4. Secure Boot / Lanzaboote sequence
Do this only after a normal encrypted boot is known-good.

**Option A: Use the helper script (recommended)**
```bash
sudo ./scripts/post-install-secureboot-tpm.sh
```
This runs `sbctl create-keys` and `sbctl enroll-keys --microsoft` for you.

**Option B: Manual steps**
1. Edit `hosts/nixos/default.nix`: set `myOS.security.secureBoot.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
3. `sudo sbctl create-keys`
4. `sudo sbctl enroll-keys --microsoft`
5. Enable Secure Boot in firmware
6. Reboot and verify: `bootctl status`, `sbctl status`

**If issues occur**: See [`RECOVERY.md`](./RECOVERY.md) "If Secure Boot breaks boot" and "If disabling Secure Boot still doesn't boot" sections.

## 5. TPM2 LUKS enrollment
Keep the recovery passphrase forever.
1. Edit `hosts/nixos/default.nix`: set `myOS.security.tpm.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos` (this enables systemd initrd)
3. Identify the correct LUKS device (`/dev/disk/by-partlabel/NIXCRYPT`)
4. Enroll TPM2: `sudo systemd-cryptenroll /dev/disk/by-partlabel/NIXCRYPT --tpm2-device=auto --tpm2-pcrs=0+7`
5. Reboot-test twice
6. If TPM measurement changes break unlock, use recovery passphrase and re-enroll

**If TPM unlock breaks**: See [`RECOVERY.md`](./RECOVERY.md) "If TPM unlock breaks" section.

## 6. Mullvad
Daily:
- service installed and available
- not required as a hard kill-switch path

Paranoid:
- connect before browsing
- run `mullvad lockdown-mode set on` for always-require-VPN
- verify DNS and IP behavior
- treat lockdown behavior as expected, not a bug
- validate killswitch: `sudo nft list ruleset`

**If network issues occur**: See [`RECOVERY.md`](./RECOVERY.md) "If the paranoid profile blocks too much network" section.

## 7. Secrets / agenix
Create encrypted secret files only after host SSH keys exist.
Examples:
- Mullvad account or recovery metadata if you choose to store it
- SSH private material if managed declaratively
- app tokens only if necessary

## 8. Scanner initialization
- Update ClamAV signatures: `sudo freshclam`
- Initialize AIDE database: `sudo aideinit`
- Verify timer is active: `systemctl list-timers | grep -E 'clamav|aide'`

## 9. Manual follow-ups
- Validate Mullvad interface names match nftables rules (adjust `vpnIfaces` in networking.nix if needed)
- Create real `.age` files under `secrets/`
- Verify USB peripherals work on paranoid (authorized_default=2 allows internal hub devices)
- Enable Bluetooth controllers: set `myOS.gaming.controllers.enable = true` in your profile
- Run `lynis audit system` and address findings
- Only then experiment with `hardenedMemory.enable = true`

## 10. Install Flatpak applications (daily profile)
The Flathub remote is configured automatically, but packages must be installed manually:
```bash
flatpak install -y flathub org.signal.Signal
flatpak install -y flathub com.spotify.Client
flatpak install -y flathub com.bitwarden.desktop
flatpak install -y flathub dev.vencord.Vesktop
flatpak install -y flathub md.obsidian.Obsidian
flatpak install -y flathub org.telegram.desktop
flatpak install -y flathub im.riot.Riot
```

## 11. Use sandboxed applications
For apps not available as Flatpak, use the bubblewrap wrappers:
- `safe-vrcx` — VRCX with UID isolation (daily profile)
- `safe-windsurf` — Windsurf with UID isolation (daily profile)

These wrappers provide UID isolation (100000:100000 unmapped from host), network namespace isolation, and minimal filesystem access.

## 12. Setup KeePassXC with permanence
KeePassXC is available in both profiles. The configuration is persisted via impermanence:
- Daily: `~/.config/keepassxc` is persisted to `@persist`
- Paranoid: `~/.config/keepassxc` is persisted to `@persist`

**Post-stability steps:**
1. Launch KeePassXC and create your database
2. Store the database in `~/Data/` (daily) or `~/Documents/` (paranoid) - these are persisted
3. Configure browser integration if needed (native messaging host already available)
4. Test: reboot and verify the database file and config survive

**Critical**: Back up your database to external media. Impermanence protects against malware but not disk failure.

## 13. Configure GnuPG and gpg-agent
GnuPG is installed but requires user-level setup.

**Post-stability steps:**
1. Generate or import your key:
   ```bash
   gpg --full-generate-key  # or gpg --import existing.key
   ```
2. Create revocation certificate and store offline:
   ```bash
   gpg --output ~/revocation-cert.asc --gen-revoke YOUR_KEY_ID
   ```
3. Configure git signing (declarative config in `modules/home/common.nix` already sets `commit.gpgsign=true`):
   ```bash
   git config --global user.signingkey YOUR_KEY_ID
   ```
4. Test commit signing: `git commit -S -m "test signed commit"`
5. Publish public key if desired: `gpg --send-keys YOUR_KEY_ID`

**Security note**: Keep primary key offline; use subkeys for daily operations. See `docs/audit/SOURCE-COVERAGE-MATRIX.md` section 9 for full GnuPG hardening guidance.

## 14. Test sudo with SUDO_KILLER
Verify sudo configuration is not vulnerable to common misconfigurations.

**Post-stability steps:**
1. Clone and run SUDO_KILLER:
   ```bash
   git clone https://github.com/TH3xACE/SUDO_KILLER.git /tmp/sudo_killer
   cd /tmp/sudo_killer
   ./sudo_killer.sh
   ```
2. Review output for any warnings about:
   - Writable sudoers files
   - Dangerous environment variables
   - Missing authentication timeouts
   - Wildcards in sudo rules
3. Verify your actual sudoers config:
   ```bash
   sudo cat /etc/sudoers
   sudo cat /etc/sudoers.d/* 2>/dev/null
   ```

**Current repo state**: sudo requires wheel group membership, root is locked, no dangerous wildcards. SUDO_KILLER should report clean.

## 15. Verify browser leak protection
Test that browsers don't leak identifying information.

**WebRTC leak test (Firefox):**
1. Open daily Firefox (or `safe-firefox` on paranoid)
2. Visit https://browserleaks.com/webrtc
3. Expected: No IP addresses shown (WebRTC disabled via `media.peerconnection.enabled=false`)

**DNS leak test:**
1. Connect to Mullvad VPN
2. Visit https://dnsleaktest.com
3. Expected: Shows Cloudflare (DoH) or Mullvad DNS, not your ISP
4. Verify system DNS: `resolvectl status` shows DNS servers from Mullvad

**Tor Browser test:**
1. Launch `safe-tor-browser` (paranoid) or install Tor Browser (daily)
2. Visit https://check.torproject.org
3. Expected: "Congratulations. This browser is configured to use Tor."

**Fingerprinting test:**
1. Visit https://coveryourtracks.eff.org
2. Expected:
   - Daily Firefox: FPP (Fingerprinting Protection) active — "some protection"
   - Paranoid safe-firefox: RFP (Resist Fingerprinting) active — "strong protection"

## 16. Gaming/VR performance baseline (daily profile only)
Verify hardening didn't break gaming performance. Compare against old config if possible.

**Prerequisites:**
- Enable controllers first: set `myOS.gaming.controllers.enable = true` in profile, rebuild
- Install Steam, VRChat, VRCX through their respective methods (Flatpak/bubblewrap)

**Performance tests:**
1. **Steam/Proton baseline:**
   - Launch a known-good game (e.g., CS2, Elden Ring, or your usual test)
   - Record FPS and frametime (ms) with MangoHud or Steam overlay
   - Compare to `PERFORMANCE-NOTES.md` baseline or your previous config
   - Expected: Within 5% of previous performance (hardening has minimal gaming impact)

2. **VR workload test:**
   - Launch VRChat or other VR application
   - Check for frame drops, stuttering, or tracking lag
   - Verify controller binding works (may need manual bind if udev rules changed)

3. **General desktop responsiveness:**
   - Alt-tab between Steam, browser, Signal
   - No visible lag or compositor stutter

**If performance degraded:**
- Check `PERFORMANCE-NOTES.md` for per-knob impact analysis
- Suspects: `hardenedMemory`, `kernelHardening.initOnFree`, `apparmor` profiles
- Temporarily disable knobs one-by-one to identify culprit

**Success criteria:**
- Gaming FPS ≥ 95% of pre-hardening baseline
- VR tracking stable, no dropped frames
- Desktop compositor smooth at 144Hz (if applicable)

## 17. External sources to review (checklist)
Review these sources post-stability to identify additional hardening opportunities:

**Install & Impermanence:**
- [ ] NixOS Minimal ISO: https://nixos.org/download/ (used for install)
- [ ] Official Manual: https://nixos.org/manual/nixos/stable/#sec-installation-manual
- [ ] FDE Wiki: https://wiki.nixos.org/wiki/Full_Disk_Encryption
- [ ] saylesss88 Impermanence: https://saylesss88.github.io/nix/hardening_NixOS.html#impermanence
- [ ] saylesss88 Encrypted Impermanence: https://saylesss88.github.io/installation/enc/encrypted_impermanence.html
- [ ] saylesss88 Encrypted Install: https://saylesss88.github.io/installation/enc/enc_install.html

**Hardening Guides (analyzed in SOURCE-COVERAGE-MATRIX.md):**
- [ ] saylesss88 Hardening NixOS: https://saylesss88.github.io/nix/hardening_NixOS.html
- [ ] Madaidan Guide: https://madaidans-insecurities.github.io/guides/linux-hardening.html
- [ ] Debunking Madaidan: https://chyrp.cgps.ch/en/debunking-madaidans-insecurities/
- [ ] Trimstray Checklist: https://github.com/trimstray/linux-hardening-checklist
- [ ] Trimstray Practical Guide: https://github.com/trimstray/the-practical-linux-hardening-guide

**Specific Topics:**
- [ ] Network Security: https://saylesss88.github.io/nix/hardening_networking.html
- [ ] GnuPG Agent: https://saylesss88.github.io/nix/gpg-agent.html
- [ ] Git Config: https://saylesss88.github.io/vcs/git.html#configure-git-declaratively

**Note**: These sources are already analyzed in `docs/audit/SOURCE-COVERAGE-MATRIX.md`. Review them to understand what was adopted vs deferred.

## 17. Monitor these hardening knobs on daily
All negligible-impact hardening is kept enabled on daily by decision. If specific issues arise, disable via `myOS.security.*` in `profiles/daily.nix`:
- **AppArmor** (`apparmor = false`) — if specific apps fail with permission errors
- **init_on_alloc** (`kernelHardening.initOnAlloc = false`) — if allocation-heavy workloads show measurable regression
- **slab_nomerge** (`kernelHardening.slabNomerge = false`) — if RAM is critically tight
- **Module blacklist** (`kernelHardening.moduleBlacklist = false`) — if you need dccp/sctp/firewire for some reason
- **Root lock** (`lockRoot = false`) — only if you need direct root login (not recommended, default=true)
- **ptraceScope** (`ptraceScope = 2`) — if VRChat EAC issues occur, daily uses 1 for compatibility
- **swappiness** (`swappiness = 30`) — if swap behavior needs tuning, daily uses 150 for zram optimization, paranoid uses 180

## 18. Wayland-only display manager roadmap
**Phase 1 (current):** X11 server runs for SDDM/NVIDIA compatibility, user sessions are Wayland-only, X apps use XWayland automatically. Acceptable tradeoff for NVIDIA compatibility.

**Phase 2 (post-stability):** After system is stable and tested, evaluate greetd + tuigreet for Wayland-native display manager. This would eliminate X11 server entirely but is experimental and may break NVIDIA compatibility. See https://wiki.nixos.org/wiki/Greetd.

**Phase 3 (October 2026):** Plasma 6.8 Wayland-exclusive release drops X11 session support entirely. At that point, switch to Plasma 6.8 and evaluate SDDM Wayland greeter (currently experimental). See https://blogs.kde.org/2025/11/26/going-all-in-on-a-wayland-future/

---

## Deferred items (post-stability decisions needed)

### Hardened compilation flags (Madaidan recommendation)
- Status: Documented only, not implemented
- Research: Madaidan Linux Hardening Guide
- Decision needed: Enable repo-wide hardened compilation? This requires significant testing for gaming/VR/NVIDIA compatibility
- Implementation: Would need `nixpkgs.config.hardeningEnable = true` or per-package overrides
- Risk: Performance regression in compute-intensive workloads

### Full nix-mineral diff analysis
- Status: Not yet analyzed
- Source: github.com/cynicsketch/nix-mineral (alpha software, different threat model)
- Decision needed: Review nix-mineral module-by-module and adopt applicable techniques?
- Scope: Kernel params, sysctl, boot settings, service hardening
- Risk: Alpha quality, may conflict with gaming requirements

### Full SUID/capability pruning program
- Manual post-stability work required
- See SOURCE-TOPIC-LEDGER.md for Madaidan/saylesss88 references

### NTS time sync replacement
- Knob not yet implemented
- May break KDE/Qt time APIs - test carefully

### Remote wipe / dead-man switch integration
- **Status**: Deferred to post-stability
- **Rationale**: Requires infrastructure design (signal service, dead-man timer, secure wipe mechanism)
- **Consideration**: Optional for paranoid profile; complex implementation for daily driver
- **Reference**: Original plan item moved from PROJECT-STATE.md

### Manual User Checks (verify personally)
**After install, personally verify these items that cannot be automated:**

| Check | How to Verify | Expected Result |
|-------|---------------|-----------------|
| **FPP vs RFP behavior** | Visit https://coveryourtracks.eff.org on daily Firefox | Should show "some protection" (FPP) not "strong protection" (RFP) |
| **Canvas randomization** | Run https://browserleaks.com/canvas, refresh page | Canvas hash should change between reloads |
| **Timezone spoofing** | Check `Date()` in browser console (FPP vs RFP differ) | FPP: your timezone; RFP: GMT/Atlantic/Reykjavik |
| **Letterboxing** | Resize browser window | FPP: no margins; RFP (paranoid): stepped margins |
| **WebRTC leak test** | https://browserleaks.com/webrtc on daily | Should show Mullvad IP if VPN active, not real IP |
| **DoH is Mullvad** | https://www.dnsleaktest.com/ | Daily: `base.dns.mullvad.net` (ads/trackers). Paranoid: `all.dns.mullvad.net` (ads/trackers/malware/gambling) |
| **Firefox Sync disabled** | about:preferences#sync on daily | Should show "Sign in to Sync" not your account |
| **Cookie behavior** | Check lock icon on any site → Cookies | Should show dFPI/cross-site blocking active |
| **ETP Strict active** | about:preferences#privacy → Enhanced Tracking Protection | Should show "Strict" selected |
| **Safe-browsing local-only** | about:config `browser.safebrowsing.downloads.remote.enabled` | Should be `false` |

**Key decision for you**: If FPP protection feels insufficient on daily, manually enable RFP:
```javascript
// In daily Firefox about:config:
privacy.resistFingerprinting = true
privacy.resistFingerprinting.letterboxing = true
```
**Tradeoff**: RFP causes more breakage (canvas warnings, timezone confusion, some sites broken).

### Dedicated entropy-hardening component
- Partially implemented: `randomize_kstack_offset=on`, `page_alloc.shuffle=1`
- Full implementation deferred due to high-risk/low-value tradeoff

---

## Post-stability experimental testing (after system is stable)
Only attempt these after the system is fully stable and all [`TEST-PLAN.md`](./TEST-PLAN.md) checks pass.

### Wayland-only display manager (Phase 2)
Experimental: Replace SDDM with greetd + tuigreet for Wayland-native DM.
- This would eliminate X11 server entirely but is experimental
- May break NVIDIA compatibility
- See: https://wiki.nixos.org/wiki/Greetd
- Enable in your profile by replacing the SDDM service with greetd configuration

**Testing after enabling:**
- Reboot and verify greetd starts
- Verify you can log in to both player and ghost
- Verify Plasma 6 Wayland session works
- Verify NVIDIA driver still loads correctly
- Verify VR stack still works (if testing on daily)
- Check `dmesg | grep -i nvidia` for driver errors
- If NVIDIA breaks, revert to SDDM immediately (see [`RECOVERY.md`](./RECOVERY.md))

### Optional paranoid-tier kernel hardening
These options are available but not enabled by default. Enable one at a time and test:

**`kernelHardening.oopsPanic = true`** (Panic on kernel oops)
- May crash system on bad driver errors
- Testing after enabling:
  - Reboot and check system boots successfully
  - Check `journalctl -b -p err` for kernel oops
  - Test gaming/VR workload to ensure no crashes
  - If system crashes on boot, revert immediately (see [`RECOVERY.md`](./RECOVERY.md))

**`kernelHardening.moduleSigEnforce = true`** (Only load signed modules)
- Breaks custom/unsigned kernel modules
- Testing after enabling:
  - Reboot and check system boots successfully
  - Verify NVIDIA driver loads: `nvidia-smi`
  - Verify VR stack works: WiVRn status
  - Check `dmesg | grep -i module` for module load failures
  - If GPU/VR breaks, revert immediately (see [`RECOVERY.md`](./RECOVERY.md))

**`kernelHardening.disableIcmpEcho = true`** (Ignore ping requests)
- Breaks some network diagnostics
- Testing after enabling:
  - Verify normal network operations still work
  - Test Mullvad VPN connectivity
  - Test ping to known hosts (should fail)
  - If network diagnostics are needed, disable temporarily

### Entropy hardening (already partially implemented)
The safe entropy hardening techniques are **already enabled automatically**:
- `randomize_kstack_offset=on` — kernel stack randomization per-syscall
- `page_alloc.shuffle=1` — randomize free page list order (enabled on paranoid, daily has it too)

**Why no manual steps needed:**
Modern CPUs (Ryzen 5 3600 included) have hardware RNG (RDRAND) providing plenty of entropy. The remaining "entropy hardening" techniques from hardening guides are **high-risk, low-value** for desktops:
- Blocking boot until entropy pool fills — can hang indefinitely
- Disabling jitter entropy — reduces randomness availability, breaks `getrandom()`
- Tightening `kernel.random.*` thresholds — causes unpredictable blocking in games/crypto

**Verification:**
```bash
# Check randomize_kstack_offset
cat /proc/cmdline | grep randomize_kstack_offset

# Check page_alloc.shuffle (paranoid should show 1, daily shows 1 too now)
sysctl vm.page_alloc.shuffle

# Check entropy availability (should be >1000 on modern hardware)
cat /proc/sys/kernel/random/entropy_avail
```

**Recommendation:** Leave as-is. The implemented techniques provide security benefit without the breakage risk of full entropy hardening.

### AppArmor profiles (currently framework-only)
AppArmor is enabled but no custom profiles are loaded. The framework provides minimal baseline protection. Add profiles only after system is stable:

**High-value profiles to consider:**
- `firefox` - restrict browser filesystem/network access
- `steam` - sandbox Steam and Proton games
- `vesktop` - restrict Discord client
- `signal-desktop` - restrict Signal (Flatpak already sandboxes this)

**Creating a basic Firefox profile:**
1. Check existing profiles: `sudo aa-status`
2. Generate profile template: `sudo aa-genprof firefox` (run Firefox through normal usage)
3. Review generated rules in `/etc/apparmor.d/`
4. Test extensively: verify all sites, downloads, extensions work
5. Enable enforce mode only after 1+ week of complain-mode testing

**Impact assessment:**
- Profile generation overhead: Minimal (one-time)
- Runtime enforcement overhead: ~1-3% on syscall-heavy apps
- Gaming impact: Depends on profile restrictiveness
  - Steam/Proton profiles can BREAK games if too restrictive
  - Test EACH game after enabling Steam profile
  - If games fail, put profile in complain mode or remove

**Why profiles may NOT be worth it for daily:**
- Flatpak already sandboxes Signal, Spotify, Bitwarden
- `safe-firefox` and `safe-vrcx` provide UID isolation beyond AppArmor
- Gaming compatibility risk: Proton runs Windows binaries that make unexpected syscalls
- Maintenance burden: Profiles need updates when apps change
- Daily threat model: Flatpak + bubblewrap may be sufficient

**Recommendation:** Skip AppArmor profiles for daily unless you have specific high-risk proprietary apps not covered by existing sandboxing. Consider for paranoid if you add non-Flatpak browsers beyond `safe-firefox`.

### Graphene-hardened allocator testing plan
The code currently uses `graphene-hardened-light` (not full), which is less aggressive:
- `myOS.security.hardenedMemory.enable = true`
- Light variant has lower stability risk than full graphene-hardened

**Your testing progression:**
1. **Test light on paranoid first** - Lower risk profile, if it breaks only affects paranoid user
2. **If light works on paranoid, try full on paranoid** - Edit `base.nix` to change provider to `graphene-hardened` (without `-light`)
3. **Test light on daily** - Only if paranoid testing succeeds and you want daily coverage
4. **Never use full on daily** - Gaming/VR/NVIDIA stability risk unacceptable for daily driver

**Testing after each enable:**
- Reboot and check system boots successfully
- Test all applications you use regularly (browser, Steam, VR, etc.)
- Check for application crashes or segfaults: `journalctl -b -p err`
- Benchmark gaming performance (frametime, FPS) to measure impact
- Monitor RAM usage for unexpected increases
- If any application crashes or performance degrades significantly, revert immediately (see [`RECOVERY.md`](./RECOVERY.md))

**Switching to full variant (paranoid only, after light succeeds):**
```bash
# Edit modules/security/base.nix:
# environment.memoryAllocator.provider =
#   lib.mkIf sec.hardenedMemory.enable "graphene-hardened";  # No -light suffix
```

---

## Blind spots audit (post-stability findings)
The following items were identified as gaps during documentation/governance audit. Items marked [FIXED] have been addressed; others require your decision.

### [FIXED] LUKS Header Backup Procedure
**Risk**: LUKS header corruption bricks the encrypted disk. Single point of failure.  
**Action**: After install, immediately back up the header:
```bash
# Backup to external media (USB, another machine, etc.)
sudo cryptsetup luksHeaderBackup /dev/disk/by-partlabel/NIXCRYPT --header-backup-file /media/external/luks-header-backup-$(date +%Y%m%d).bin

# Store backup passphrase separately from the backup file
# Test header restore on a spare LUKS container first - never test on live data
```
**Verification**: Confirm backup file exists and is readable: `ls -la /media/external/luks-header-backup-*.bin`

### [FIXED] EFI Partition Backup/Verification
**Risk**: EFI partition corruption breaks boot; no rollback plan.  
**Action**: Back up EFI contents and create verification script:
```bash
# One-time backup after first successful boot
sudo tar czf /persist/efi-backup-$(date +%Y%m%d).tar.gz -C /boot/efi .

# Periodic verification (add to weekly cron or timer)
bootctl status  # Should show "Secure Boot: disabled" or "enabled" consistently
sbctl status    # Shows key enrollment status

# Check for EFI corruption signs
dmesg | grep -i efi | grep -i -E "(error|corrupt|fail)"
```
**Storage**: Keep `/persist/efi-backup-*.tar.gz` on external media, not just `@persist`.

### [TODO] fstrim/discard Configuration
**Risk**: SSD performance degradation on LUKS+Btrfs without discard.  
**Decision needed**: Enable periodic fstrim timer?
```bash
# Check current discard support
lsblk -D /dev/nvme0n1

# Option A: Enable periodic fstrim (safer, no real-time security implications)
# services.fstrim.enable = true; in your config

# Option B: Enable real-time discard (dm-crypt has security considerations)
# boot.initrd.luks.devices.cryptroot.allowDiscards = true;
# Risk: Discard may leak some information about filesystem structure
```
**Tradeoff**: fstrim timer has no security risk but is less timely; discard enables TRIM immediately but has theoretical info-leak side channels.

### [TODO] Hibernation Policy
**Risk**: swap file + tmpfs root + encryption = hibernation complexity. 16GB RAM + 8GB swap = hibernation will fail or be unreliable.  
**Decision needed**: Explicitly disable hibernation or resize swap?
```bash
# Current: check if hibernation could even work
swapon -s  # Shows swap file size
free -h    # Shows RAM size
# If RAM > swap, hibernation will fail

# Option A: Disable hibernation explicitly
# powerManagement.enable = false; in config

# Option B: Increase swap to RAM size + 2GB (~18GB for your system)
# Requires recreating @swap subvolume with larger swapfile
```
**Note**: NVIDIA proprietary drivers often have hibernation issues regardless. Documented tradeoff in `PERFORMANCE-NOTES.md`.

### [TODO] Yubikey/FIDO2/Passkey Support
**Risk**: Modern authentication standards absent from PAM configuration.  
**Decision needed**: Enable FIDO2/U2F for sudo/auth?
```bash
# Check if hardware supports FIDO2
lsusb | grep -i -E "(yubi|fido|u2f)"

# Implementation would require:
# security.pam.u2f.enable = true;
# users.users.player.extraGroups = [ "u2f" ];
# Touch confirmation for sudo/su operations
```
**Paranoid consideration**: Hardware-backed MFA is table stakes for "paranoid" tier. Consider for ghost user.

### [TODO] WireGuard Module Security Audit
**Risk**: `wg-mullvad` interface in nftables rules assumes WireGuard module security. Module bugs = VPN bypass.  
**Decision needed**: Monitor for WireGuard CVEs? Use kernel-level network namespace instead?
```bash
# Monitor WireGuard module security
# Subscribe to: https://www.wireguard.com/security/
# Check loaded module version: modinfo wireguard | grep version

# Defense in depth: The nftables killswitch is already defense-in-depth
# If Mullvad's daemon is compromised, killswitch provides second layer
```
**Current**: Defense-in-depth exists (nftables killswitch), but explicit WireGuard hardening not implemented.

### [TODO] Bootloader Recovery Documentation Enhancement
**Risk**: Lanzaboote/Secure Boot lockout scenarios beyond current RECOVERY.md coverage.  
**Gap**: No explicit "Secure Boot disabled, system still won't boot" procedure.  
**Decision needed**: Create emergency ISO with pre-enrolled keys for recovery?
```bash
# Extended recovery procedure (also documented in RECOVERY.md):
# 1. If even disabling SB in firmware doesn't help:
#    - Boot NixOS installer USB
#    - cryptsetup open /dev/nvme0n1p2 cryptroot
#    - mount /dev/mapper/cryptroot /mnt
#    - mount /dev/nvme0n1p1 /mnt/boot
#    - nixos-enter
#    - sbctl verify  # Check which files have signature issues
#    - sbctl reset  # Clear signature database (nuclear option)
# 2. If Lanzaboote completely broken:
#    - Temporarily switch to standard systemd-boot:
#    - boot.loader.systemd-boot.enable = true;
#    - boot.lanzaboote.enable = false;
#    - nixos-rebuild switch
```
**If issues occur**: See [`RECOVERY.md`](./RECOVERY.md) "If Secure Boot breaks boot" and "If disabling Secure Boot still doesn't boot" sections.

### [FIXED] Bubblewrap GPU Passthrough Acknowledgment
**Risk**: `safe-firefox` uses `--dev-bind /dev/dri` which exposes GPU attack surface. GPU drivers have history of DMA attacks.  
**Fix**: Documentation updated to acknowledge this limitation.  
**Current claim**: "National-level" isolation is slightly overstated for GPU-bound apps.  
**Actual isolation**: UID namespace + network namespace + FS isolation = strong, but GPU passthrough is a known escape vector (historical GPU driver bugs allow DMA attacks).  
**Recommendation**: For maximum isolation of untrusted content, use VM isolation (`vmIsolation.enable`) instead of bubblewrap, or run `safe-firefox` on a system without GPU passthrough (software rendering).

### [FIXED] SSH Host Key Rotation Policy
**Risk**: Impermanence wipes machine identity; host keys persist but no rotation procedure documented.  
**Fix**: Added rotation procedure.  
**Procedure**:
```bash
# After any reinstall (impermanence wipe or fresh install):
# 1. Check if keys need rotation (compare with backup)
ssh-keygen -lf /persist/etc/ssh/ssh_host_rsa_key.pub

# 2. If rotating:
sudo rm /persist/etc/ssh/ssh_host_*key*
sudo ssh-keygen -A -f /persist/etc/ssh  # Regenerate
sudo systemctl restart sshd

# 3. Update known_hosts on remote systems:
ssh-keyscan -H <hostname> >> ~/.ssh/known_hosts  # On remote machine

# 4. Document key fingerprints in password manager:
ssh-keygen -lf /persist/etc/ssh/ssh_host_ed25519_key.pub
```

### [TODO] Thunderbolt/DMA Attack Surface
**Risk**: No IOMMU for external devices (Thunderbolt, PCI hotplug). DMA attacks bypass all OS-level hardening.  
**Decision needed**: Disable Thunderbolt entirely in firmware? Enable IOMMU for external ports?
```bash
# Check if system has Thunderbolt
lspci | grep -i thunderbolt

# Check current IOMMU status
dmesg | grep -i iommu

# Mitigation options:
# 1. BIOS/UEFI: Disable Thunderbolt entirely if not needed
# 2. Kernel param: thunderbolt.disable=1 (if module loaded)
# 3. IOMMU for Thunderbolt: Requires ACS override patch, complex

# Current status: USB restriction (usbRestrict) exists but Thunderbolt
# (PCIe-over-cable) has separate attack surface not addressed
```
**Paranoid consideration**: Thunderbolt allows DMA attacks that bypass all OS hardening. Consider physical disabling in firmware for paranoid profile.

---

**Summary**: 4 items fixed (LUKS header backup, EFI backup, bubblewrap acknowledgment, SSH rotation); 6 items require your explicit decision.
