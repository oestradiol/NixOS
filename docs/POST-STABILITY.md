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

**Prerequisite (both options):**
1. Edit `hosts/nixos/default.nix`: set `myOS.security.secureBoot.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos`

**Option A: Use the helper script (recommended)**
```bash
sudo ./scripts/post-install-secureboot-tpm.sh
```
This runs `sbctl create-keys` and `sbctl enroll-keys --microsoft` for you.

**Option B: Manual steps**
1. `sudo sbctl create-keys`
2. `sudo sbctl enroll-keys --microsoft`

**Final steps (both options):**
1. Enable Secure Boot in firmware setup
2. Reboot and verify: `bootctl status`, `sbctl status`

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

## 6. VPN

### Daily: Mullvad App (convenience mode)

The Mullvad app is used for ease of use with features like:
- Automatic key rotation
- Multihop connections
- GUI controls
- Built-in lockdown-mode (`mullvad lockdown-mode set on`)

No strict killswitch is enforced at the OS level - the app manages its own firewall state.

### Paranoid: Self-Owned WireGuard (deterministic mode)

> **ARCHITECTURE**: NixOS owns the tunnel state AND firewall policy. Mullvad is only the server provider.
> 
> Memory anchor: **Mullvad as provider, NixOS as authority**

**Key properties**:
- Single source of truth: WireGuard config generates firewall rules
- Fixed interface name: `wg-mullvad` (hardcoded, no drift)
- Default-deny nftables policy: only bootstrap (DHCP/NDP), DNS through tunnel, WG handshake, and tunnel traffic allowed
- No Mullvad app daemon: `services.mullvad-vpn.enable = false`
- Deterministic, auditable, self-owned enforcement

**Required setup** (see PRE-INSTALL.md Section 15):
```nix
myOS.security.wireguardMullvad = {
  enable = lib.mkForce true;
  privateKeyFile = config.age.secrets.wg-private-key.path;
  address = "10.64.x.x/32";        # Your Mullvad-assigned IP
  endpoint = "us-nyc-wg-001.mullvad.net:51820";  # Your chosen server
  serverPublicKey = "<server-pubkey>";  # From Mullvad config
  dns = "10.64.0.1";               # Mullvad DNS through tunnel
};
```

**Verification commands**:
```bash
# Check WireGuard interface is up
ip link show wg-mullvad

# Check tunnel is established (should show handshake)
sudo wg show wg-mullvad

# Verify routing (default should be via wg-mullvad)
ip route | grep default

# Test for DNS leaks (should show Mullvad DNS)
dig +short whoami.mullvad.net

# Test for IP leaks (should show Mullvad exit IP)
curl https://am.i.mullvad.net/connected

# Validate killswitch: check nftables policy is default-deny
sudo nft list table inet filter
# Should see: chain output { type filter hook output priority filter; policy drop; ... }
```

**Killswitch test** (confirm no leaks when tunnel down):
```bash
# Stop WireGuard - all outbound should fail
sudo systemctl stop wg-quick-wg-mullvad
curl https://example.com  # Should hang/fail
sudo systemctl start wg-quick-wg-mullvad
```

**Known limitations**:
- DNS for hostname endpoints: When using hostname endpoints, the nftables output chain permanently allows non-WireGuard DNS on port 53 (UDP and TCP) to resolve the endpoint hostname. This is a standing exception, not time-limited bootstrap.
  - **IP endpoints (recommended for paranoid)**: No DNS exception - endpoint is already an IP address
  - **Hostname endpoints**: Standing DNS exception allows DNS queries on non-WG interfaces to resolve the endpoint hostname
    - This is a necessary trade-off for hostname-based configs
    - DNS exposure is persistent as long as a hostname endpoint is configured
    - For maximum security, use literal IP endpoints instead of hostnames
- No automatic key rotation (unlike Mullvad app) - rotate keys manually via Mullvad web interface
- No multihop or obfuscation features (plain WireGuard)
- No split tunneling (full killswitch: all traffic through tunnel or blocked)

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
- Verify timers are active: `systemctl list-timers | grep -E 'clamav|aide'`
- Test scans manually:
  - `sudo systemctl start clamav-impermanence-scan` (daily impermanence check)
  - `sudo systemctl start clamav-deep-scan` (comprehensive weekly check)
- Review logs: `/var/log/clamav-impermanence-scan.log`, `/var/log/clamav-deep-scan.log`

## 9. Manual follow-ups
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
```

## 11. Use sandboxed applications

For apps not available as Flatpak, use the bubblewrap wrappers:
- `safe-vrcx` — VRCX with UID isolation (daily profile)
- `safe-windsurf` — Windsurf with UID isolation (daily profile)

**Isolation provided:**
- UID isolation (100000:100000 unmapped from host)
- Process namespace isolation (IPC, PID, UTS)
- Capability dropping (`--cap-drop ALL`)
- Minimal tmpfs home and /tmp

**Isolation limitations (read carefully):**
- **Network namespace is NOT isolated** — apps have full host network access
- **Broad host paths bound read-only**: `/run`, `/etc` — this exposes some host runtime state
  - Daily profile: `/var` is also bound for compatibility with some apps
  - Paranoid profile: `/var` is NOT bound (stricter isolation) — apps use `/run` for runtime state
- **GPU passthrough** (`--dev-bind /dev/dri`) — GPU drivers are a known escape vector via DMA attacks
- These wrappers provide **helpful containment**, not "trustworthy hostile-content isolation"

**For maximum isolation of untrusted content**, use VM isolation (`sandbox.vms`) instead of bubblewrap.

## 12. Setup KeePassXC with permanence (paranoid profile only)
KeePassXC is available in the paranoid profile only. Daily uses Bitwarden (Flatpak). The configuration is persisted via impermanence:
- Paranoid only: `~/.config/keepassxc` is persisted to `@persist`

**Post-stability steps:**
1. Launch KeePassXC and create your database
2. Store the database in `~/Documents/` - this is persisted
3. Configure browser integration if needed (see caveats below)
4. Test: reboot and verify the database file and config survive

**Native messaging caveats**:
- Native messaging for browser integration may break under D-Bus filtering
- If using sandboxed browsers (`safe-firefox`), additional allowlists may be needed
- For maximum reliability, use KeePassXC's auto-type feature instead of browser integration

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
3. Expected:
   - Daily: May show Mullvad IP if VPN active (WebRTC enabled for gaming/video calls)
   - Paranoid (`safe-firefox`): No IP addresses shown (WebRTC disabled via `media.peerconnection.enabled=false`)

**DNS leak test:**
1. Connect to Mullvad VPN
2. Visit https://dnsleaktest.com
3. Expected: Shows Mullvad DNS only (DoH is disabled), not your ISP
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

## 18. Monitor these hardening knobs on daily
All negligible-impact hardening is kept enabled on daily by decision. If specific issues arise, disable via `myOS.security.*` in `profiles/daily.nix`:
- **AppArmor** (`apparmor = false`) — if specific apps fail with permission errors
- **init_on_alloc** (`kernelHardening.initOnAlloc = false`) — if allocation-heavy workloads show measurable regression
- **slab_nomerge** (`kernelHardening.slabNomerge = false`) — if RAM is critically tight
- **Module blacklist** (`kernelHardening.moduleBlacklist = false`) — if you need dccp/sctp/firewire for some reason
- **Root lock** (`lockRoot = false`) — only if you need direct root login (not recommended, default=true)
- **ptraceScope** (`ptraceScope = 2`) — if VRChat EAC issues occur, daily uses 1 for compatibility
- **swappiness** (`swappiness = 30`) — if swap behavior needs tuning, daily uses 150 for zram optimization, paranoid uses 180

## 19. Wayland-only display manager roadmap
**Phase 1 (current):** X11 server runs for SDDM/NVIDIA compatibility, user sessions are Wayland-only, X apps use XWayland automatically. Acceptable tradeoff for NVIDIA compatibility.

**Phase 2 (post-stability):** After system is stable and tested, evaluate greetd + tuigreet for Wayland-native display manager. This would eliminate X11 server entirely but is experimental and may break NVIDIA compatibility. See https://wiki.nixos.org/wiki/Greetd.

**Phase 3 (October 2026):** Plasma 6.8 Wayland-exclusive release drops X11 session support entirely. At that point, switch to Plasma 6.8 and evaluate SDDM Wayland greeter (currently experimental). See https://blogs.kde.org/2025/11/26/going-all-in-on-a-wayland-future/

### XWayland compatibility testing (pre-Plasma 6.8)
Before Plasma 6.8 release, test all critical applications under XWayland:
```bash
# Verify XWayland is handling X apps
ps aux | grep Xwayland

# Test specific apps that may have X dependencies
xeyes        # Should display via XWayland
xev          # Should capture events
steam        # Should run (Proton games use XWayland)
vrchat       # Should run via XWayland or native Wayland
```

**If apps fail under XWayland:**
1. Check `WAYLAND_DISPLAY` environment variable is set
2. Verify `XWAYLAND` is running: `pgrep -a Xwayland`
3. Test with explicit X backend: `GDK_BACKEND=x11 firefox`
4. Document workarounds in `PROJECT-STATE.md`

**To disable X server (Phase 2/3 goal):**
1. Set `services.xserver.enable = false`
2. Enable native Wayland display manager (greetd/experimental SDDM Wayland)
3. Verify all apps still function
4. Remove X11-related packages from system

---

## Known Issues (Fixed - Verify After Install)

These bugs were identified during audit and fixed in code. Verify they work correctly on your installation.

### Btrfs Swapfile Compression Bug (FIXED)

**Original issue**: The install script mounted `@swap` subvolume with `compress=zstd`, which breaks swapfile requirements.

**Fix applied**: Changed to `noatime,nodatacow` mount options.

**Verify after install**:
```bash
# Check swap subvolume mount options
findmnt /swap
# Should show: noatime, nodatacow (NO compress=zstd)

# Verify swapfile is active
swapon --show
free -h

# Check for swap errors in dmesg
dmesg | grep -i swap
```

**If swap fails**: See [`RECOVERY.md`](./RECOVERY.md) "If swap activation fails" section.

### WireGuard Endpoint Parser Bug (FIXED)

**Original issue**: Endpoint parsing used `splitString ":"` which breaks IPv6, and `toInt` on hostname parts caused evaluation errors.

**Fix applied**: Regex-based pattern matching using `builtins.match` for bracketed IPv6, IPv4, and hostname patterns.

**Verify after install**:
```bash
# Test paranoid profile builds (evaluation-time check)
nixos-rebuild build --flake /etc/nixos#nixos
ls result/specialisation/paranoid/

# If paranoid WireGuard is configured, verify endpoint parsing
# (If endpoint format is invalid, build will fail with assertion)
```

**Valid endpoint formats**:
- `us-nyc-wg-001.mullvad.net:51820` (hostname:port)
- `1.2.3.4:51820` (IPv4:port)
- `[2606:4700::1111]:51820` (bracketed IPv6:port)

**Invalid (will fail assertion)**:
- `2001:db8::1:51820` (unbracketed IPv6 - ambiguous)
- `hostname` (missing port)
- `hostname:abc` (non-numeric port)
- `hostname:70000` (port out of range)

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

### VM boot testing for automated verification
- Status: Not implemented
- Value: Automated boot testing in VM would catch config errors before hardware deployment
- Implementation: Use `nixos-rebuild build-vm` or QEMU/KVM with minimal config
- Scope: Test both daily and paranoid profiles boot successfully
- Risk: May not fully replicate hardware-specific behavior (GPU, TPM, Secure Boot)
- Decision needed: Add to verification pipeline?

---

## Verification Pipeline Gaps

This repo currently provides: static code review, evaluation-time assertions (flake checks), install-time validation (swapfile test), and manual test plan documentation.

The following verification methods are **not implemented** and represent gaps in the verification pipeline:

### 1. Automated VM boot testing
- **Status**: Not implemented (documented as deferred above)
- **What's missing**: CI pipeline that boots both profiles in VM to verify config correctness
- **Implementation**: GitHub Actions or local pre-commit hook using `nixos-rebuild build-vm`
- **Value**: Catches config errors before hardware deployment
- **Limitation**: Cannot test GPU/TPM/Secure Boot hardware-specific behavior

### 2. Hardware CI / automated hardware testing
- **Status**: Not implemented
- **What's missing**: Automated testing on actual hardware with target configuration
- **Implementation**: Hardware test matrix with at least one machine matching the target config (NVIDIA GPU, TPM, Secure Boot)
- **Value**: Verifies hardware-specific interactions that VM cannot replicate
- **Limitation**: Requires physical hardware infrastructure

### 3. Runtime exploit testing / adversarial validation
- **Status**: Not implemented
- **What's missing**: Adversarial testing of firewall rules, sandbox escape attempts, privilege escalation checks
- **Implementation**: Security testing suite (nmap, exploit attempts, sandbox escape verification)
- **Value**: Verifies hardening claims under adversarial conditions
- **Limitation**: Requires security expertise and controlled testing environment

### 4. Measured performance benchmarks
- **Status**: Partially documented (manual post-install in PERFORMANCE-NOTES.md)
- **What's missing**: Automated performance regression testing with baseline measurements
- **Implementation**: Benchmark suite measuring frametime, latency, boot time, memory usage
- **Value**: Empirical validation of performance impact claims
- **Limitation**: Requires consistent hardware and controlled test conditions

### 5. Recovery scenario validation
- **Status**: Documented but not tested
- **What's missing**: Runtime validation of recovery procedures for agenix/secret decryption failures, WireGuard secret path unavailability, and paranoid network blocking scenarios
- **Implementation**: Manual test on actual hardware or recovery environment to verify each recovery scenario in RECOVERY.md executes correctly
- **Value**: Confirms recovery procedures work when needed (critical for paranoid profile where WireGuard failure blocks all network)
- **Limitation**: Requires inducing failure states or simulating them in test environment

### Current verification level
With these gaps, the repo is appropriately characterized as:
- **Audited**: Code reviewed against external sources
- **Statically checked**: Evaluation-time assertions catch config errors
- **Installation-path improved**: Install-time validation catches deployment errors
- **Documentation-governed**: All changes must update relevant docs

Not yet:
- **Fully verified**: No automated VM/hardware boot testing
- **Pentested**: No adversarial runtime testing
- **Empirically benchmarked**: Performance claims are theoretical estimates

### NTS time sync replacement
- Knob not yet implemented
- May break KDE/Qt time APIs - test carefully

### Memory-safe languages policy
- **Status**: Documented as doctrine, not enforceable in repo
- **Rationale**: Encouraging Rust/Go/etc. over C/C++ for new code is valuable but not a NixOS configuration option
- **Implementation**: Would require:
  - Package overlay preferring memory-safe implementations
  - Development environment defaults (cargo, go tools)
  - Documentation guidelines for any custom scripts
- **Scope**: Best-practice note; cannot be enforced at system level

### Remote wipe / dead-man switch integration
- **Status**: Deferred to post-stability
- **Rationale**: Requires infrastructure design (signal service, dead-man timer, secure wipe mechanism)
- **Consideration**: Optional for paranoid profile; complex implementation for daily driver
- **Reference**: Original plan item moved from PROJECT-STATE.md

### NVIDIA Pascal / GTX 1060 driver branch strategy under unstable
- **Status**: Risk actively tracked; temporary fallback in place
- **Rationale**: nixpkgs unstable currently has a packaging gap for `legacy_580` (issue #503740)
- **Temporary fallback**: Using `nvidiaPackages.production` branch instead of ideal `legacy_580`
- **Current state**: `production` still supports Pascal (GTX 1060), but this will eventually change
- **Risk**: When Pascal support is dropped from `production`, builds may fail or GPU may not function
- **Re-evaluation trigger**: Switch back to `legacy_580` when:
  1. nixpkgs issue #503740 is resolved AND
  2. `legacy_580` is properly exposed in `nvidiaPackages` AND
  3. A test build confirms it evaluates and builds cleanly
- **Monitoring**: Track https://github.com/NixOS/nixpkgs/issues/503740
- **Fallback if production drops Pascal first**: Pin nixpkgs to a known-good revision or carry a local nixpkgs patch

### AIDE vs ClamAV: Choose your scanning model
Both AIDE and ClamAV are enabled by default, but serve different purposes:

**ClamAV** (signature-based):
- "Is this file known malware?"
- Catches known threats via virus database
- Daily + weekly scans of persisted directories
- **Recommendation**: Keep enabled

**AIDE** (integrity-based):
- "Did this file change unexpectedly?"
- Catches unknown malware / rootkits by detecting file modifications
- Weekly scans of high-value persisted paths only
- Generates noise if files legitimately change

**If you prefer ClamAV-only** (disable AIDE):
```nix
# In your profile configuration
myOS.security.aide.enable = false;
```

**Trade-offs**:
- AIDE + ClamAV: Maximum coverage (known + unknown threats), but AIDE may alert on legitimate changes
- ClamAV-only: Fewer false positives, but zero-day malware won't be detected until signatures exist

### D-Bus filtering for sandboxed browsers and apps
**Status**: Enabled by default in paranoid; optional in daily

**The problem**: Bubblewrap docs warn that unfiltered D-Bus access can allow systemd exploitation. Sandboxed browsers and apps bind `/run` read-only, exposing full D-Bus sockets.

**Scope**: D-Bus filtering now applies to both sandboxed browsers (`safe-firefox`, `safe-tor-browser`, `safe-mullvad-browser`) and sandboxed apps (`safe-vrcx`, `safe-windsurf`).

**The solution**: `xdg-dbus-proxy` provides filtered D-Bus access with a deny-by-default policy.

**D-Bus namespace status** (verified via research):
- `safe-firefox`: `--own=org.mozilla.firefox.*` (correct for Firefox)
- `safe-tor-browser`: `--own=org.mozilla.firefox.*` (Tor uses org.mozilla currently, not org.torproject)
- `safe-mullvad-browser`: `--own=org.mozilla.firefox.*` (Mullvad uses org.mozilla currently, not net.mullvad)

**Reference**: https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050
**MONITOR**: Check if Tor/Mullvad change D-Bus namespace in future releases

**Profile defaults**:
- **Paranoid**: `dbusFilter = true` (filtered D-Bus for stronger isolation)
- **Daily**: `dbusFilter = false` (full D-Bus access for compatibility)

**To enable in daily** (optional hardening):
```nix
myOS.security.sandbox.dbusFilter = true;
```

**To disable in paranoid** (if functionality breaks):
```nix
myOS.security.sandbox.dbusFilter = lib.mkForce false;
```

**Test in paranoid** (verify D-Bus filtering works correctly):
1. Launch `safe-firefox` and verify it starts
2. Test browser extensions (may break with filtering)
3. Test file pickers and desktop notifications (via xdg-dbus-proxy)
4. Check PipeWire/WebRTC audio/video still works
5. If anything breaks, disable: `dbusFilter = lib.mkForce false`

**Test in daily** (only if you enable it):
Same steps as paranoid. Note that D-Bus filtering is disabled by default in daily for maximum compatibility.

**D-Bus implementation by profile**:

| Profile | Session Bus | System Bus | D-Bus Filter | Implementation |
|---------|-------------|------------|--------------|------------------|
| **Daily** | Selective `/run` binds (XDG runtime + direct system socket) | Direct `/run/dbus/system_bus_socket` | `false` | `mkSandboxedBrowser` with `cfg.dbusFilter = false` |
| **Paranoid** | Filtered via `xdg-dbus-proxy` | Filtered via `xdg-dbus-proxy` | `true` | `mkSandboxedBrowser` with `cfg.dbusFilter = true` |

**Daily D-Bus binds** (when `dbusFilter = false`):
- `--ro-bind /run/user/$(id -u) /run/user/$(id -u)` - XDG runtime directory
- `--ro-bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket` - System D-Bus socket
- Full session bus access via XDG_RUNTIME_DIR/bus (if present)
**Paranoid D-Bus policy** (when `dbusFilter = true`):
- **Session bus**: `--own=org.mozilla.firefox.* --talk=org.freedesktop.portal.* --talk=org.a11y.Bus --talk=org.mpris.MediaPlayer2.* --broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/*`
- **System bus**: `--talk=org.freedesktop.NetworkManager --talk=org.freedesktop.login1`

**D-Bus policy details** (all sandboxed browsers use same policy):

| Policy | Session Bus | System Bus |
|--------|-------------|------------|
| **Own namespace** | `org.mozilla.firefox.*` | N/A |
| **Portal access** | `org.freedesktop.portal.*` | N/A |
| **Portal signals** | `--broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/*` | N/A |
| **Accessibility** | `org.a11y.Bus` | N/A |
| **Media control** | `org.mpris.MediaPlayer2.*` | N/A |
| **System services** | N/A | `NetworkManager`, `login1` |

**Implementation notes**:
- `mkSandboxedBrowser` function implements all D-Bus logic
- `dbusFilter` option controls filtered vs direct mode
- Both session and system buses are filtered when enabled
- Deny-by-default policy with explicit allowlist

**What the wrapper STILL exposes (outside D-Bus)**:
- **GPU access** (`/dev/dri` bind) — known escape vector via DMA
- **Display server** (Wayland/X11 socket) — full desktop interaction
- **PipeWire** (audio/video capture socket)
- **Network** (no network namespace isolation) — full host network access
- **Host filesystem** (broad read-only binds: `/etc`, `/var`, `/run`)

**Verdict**: The D-Bus filter reduces **one IPC surface**. It does not provide "trustworthy browser isolation" against motivated attackers. For hostile content, use VM isolation.

**For maximum isolation**: Use `sandbox.vms` and run browsers in a VM instead of relying on bubblewrap D-Bus filtering.

### Manual User Checks (verify personally)
**After install, personally verify these items that cannot be automated:**

| Check | How to Verify | Expected Result |
|-------|---------------|-----------------|
| **FPP vs RFP behavior** | Visit https://coveryourtracks.eff.org on daily Firefox | Should show "some protection" (FPP) not "strong protection" (RFP) |
| **Canvas randomization** | Run https://browserleaks.com/canvas, refresh page | Canvas hash should change between reloads |
| **Timezone spoofing** | Check `Date()` in browser console (FPP vs RFP differ) | FPP: your timezone; RFP: GMT/Atlantic/Reykjavik |
| **Letterboxing** | Resize browser window | FPP: no margins; RFP (paranoid): stepped margins |
| **WebRTC leak test** | https://browserleaks.com/webrtc on daily | Should show Mullvad IP if VPN active, not real IP |
| **DNS via VPN** | https://www.dnsleaktest.com/ | Daily: System/VPN DNS (no DoH). Paranoid: VPN server DNS `all.dns.mullvad.net` (ads/trackers/malware/gambling) |
| **Firefox Sync disabled** | about:preferences#sync on daily | Should show "Sign in to Sync" not your account |
| **Cookie behavior** | Check lock icon on any site → Cookies | Should show dFPI/cross-site blocking active |
| **ETP Strict active** | about:preferences#privacy → Enhanced Tracking Protection | Should show "Strict" selected |
| **Safe-browsing local-only** | about:config `browser.safebrowsing.downloads.remote.enabled` | Should be `false` |
| **Machine-id (paranoid)** | `cat /etc/machine-id` | Should show `b08dfa6083e7567a1921a715000001fb` (Whonix shared ID) |
| **WireGuard killswitch active** | Paranoid: `sudo nft list table inet filter | grep 'policy drop'` | Should show default-deny policy; `wg-mullvad` interface explicitly allowed |
| **WireGuard tunnel established** | `sudo wg show wg-mullvad` | Should show handshake and transfer stats |
| **No leaks when tunnel down** | `sudo systemctl stop wg-quick-wg-mullvad; curl https://example.com; sudo systemctl start wg-quick-wg-mullvad` | Curl should fail/timeout when tunnel down; succeeds when up |

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
- `page_alloc.shuffle=1` — randomize free page list order (enabled on both profiles)

**Why no manual steps needed:**
Modern CPUs (Ryzen 5 3600 included) have hardware RNG (RDRAND) providing plenty of entropy. The remaining "entropy hardening" techniques from hardening guides are **high-risk, low-value** for desktops:
- Blocking boot until entropy pool fills — can hang indefinitely
- Disabling jitter entropy — reduces randomness availability, breaks `getrandom()`
- Tightening `kernel.random.*` thresholds — causes unpredictable blocking in games/crypto

**Verification:**
```bash
# Check randomize_kstack_offset
cat /proc/cmdline | grep randomize_kstack_offset

# Check page_alloc.shuffle (paranoid should show 1, daily shows 1)
sysctl vm.page_alloc.shuffle

# Check entropy availability (should be >1000 on modern hardware)
cat /proc/sys/kernel/random/entropy_avail
```

**Recommendation:** Leave as-is. The implemented techniques provide security benefit without the breakage risk of full entropy hardening.

### Secure Boot end-state: modules_disabled=1 (optional paranoid hardening)

**Current baseline**: `module.sig_enforce=1` (only signed modules load)

**Optional end-state**: `kernel.modules_disabled=1` (no new modules after boot)

**Difference**:
- `module.sig_enforce=1`: Validates module signatures but allows runtime module loading
- `modules_disabled=1`: One-way toggle; once set, NO new modules can load until reboot

**Why this is staged to POST-STABILITY**:
- `modules_disabled=1` is a **one-way operation** — you cannot re-enable module loading without rebooting
- Required modules must be loaded at boot (NVIDIA, WireGuard, etc.) — if any are missing, system may not function
- `module.sig_enforce=1` provides most of the security benefit without the operational risk

**To enable (paranoid only, after stability verified)**:
```nix
# In profiles/paranoid.nix:
myOS.security.kernelHardening.modulesDisabled = lib.mkForce true;
```

**Prerequisites before enabling**:
1. System must be stable for 2+ weeks with all hardware working
2. Verify all required modules load at boot:
   ```bash
   lsmod | grep -E "(nvidia|wireguard|kvm|amdgpu)"  # Your required modules
   ```
3. Test that no late-loading modules are needed (USB devices, etc.)
4. Have recovery USB ready (if modules_disabled breaks something, you can't load fixes)

**Verification after enabling**:
```bash
# Check modules_disabled is active
sysctl kernel.modules_disabled  # Should show 1

# Try to load a module (should fail)
sudo modprobe floppy  # Or any unused module
# Expected: "module loading is disabled"
```

**Recovery if broken**:
1. Reboot into previous generation (modules_disabled resets to 0 on boot)
2. Disable the option in profile, rebuild
3. If can't boot: use NixOS installer USB, mount, edit profile, rebuild

**Recommendation**: Keep `modulesDisabled = false` (default). The marginal security gain over `module.sig_enforce=1` is small; the operational risk is high. Enable only if your threat model requires absolute kernel attack surface reduction.

---

### Kernel lockdown mode (optional paranoid hardening)

**Status**: Not implemented by default. May auto-enable with Secure Boot depending on kernel config.

**What it is**: Linux Security Module (LSM) that prevents direct/indirect kernel image access. Added in kernel 5.4.

**Two modes**:
- **Integrity** (`lockdown=integrity`): Less restrictive - prevents kernel modification
- **Confidentiality** (`lockdown=confidentiality`): Most restrictive - also blocks kernel memory inspection

**What it blocks**:
- `/dev/mem`, `/dev/kmem`, `/dev/kcore`, `/dev/ioports`
- BPF kprobes, MSR register access, PCI BAR access
- ACPI table override, debugfs access
- Unsigned kexec, unencrypted hibernation

**To enable**:
```nix
# In modules/core/boot.nix, add to kernelParams:
boot.kernelParams = [
  "lsm=lockdown"           # Enable lockdown LSM
  "lockdown=integrity"     # Or "confidentiality" for maximum restriction
];
```

**Prerequisites before enabling**:
1. System stable with Secure Boot working (lockdown often auto-enables with SB)
2. Check if already active: `dmesg | grep -i lockdown`
3. **CRITICAL**: Test NVIDIA driver compatibility:
   ```bash
   # After enabling, verify NVIDIA still works
   nvidia-smi
   glxinfo | grep "NVIDIA"
   # Test game/Steam launch
   ```
4. Verify debug tools still work if needed: `perf`, `bpftool`, `dd` to `/dev/mem` (should fail)

**Verification after enabling**:
```bash
# Check lockdown is active
dmesg | grep -i "lockdown:.*mode"
# Should show: "Lockdown: integrity" or "Lockdown: confidentiality"

# Test restriction
echo 1 | sudo tee /dev/mem  # Should fail with "Lockdown: ... is restricted"
```

**Recovery if broken**:
1. Remove kernel parameters from boot menu (press 'e' in systemd-boot)
2. Boot, then edit `modules/core/boot.nix` to remove lockdown params
3. Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#nixos`

**Trade-offs**:
- **Pro**: Major kernel attack surface reduction; prevents many kernel exploitation techniques
- **Con**: May break NVIDIA proprietary driver (needs kernel access), debugging tools, some hardware monitoring
- **Auto-enable**: Many kernels auto-enable lockdown when Secure Boot is active

**Recommendation**: Test after Secure Boot is stable. Start with `integrity` mode. Skip if NVIDIA breaks or if you need debugging access.

---

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

## 22. System services verification

The following services are enabled but tested implicitly via desktop functionality. Verify they work:

### polkit (PolicyKit)
- [ ] Authentication dialogs work (mounting USB drives, changing network settings)
- [ ] `systemctl status polkit` shows active (running)
- [ ] No polkit errors in `journalctl -u polkit`

### udisks2 (Disk Management)
- [ ] USB drives auto-mount when inserted
- [ ] `systemctl status udisks2` shows active (running)
- [ ] KDE partition manager or GNOME disks can view drive info

### fwupd (Firmware Updates)
- [ ] `fwupdmgr get-devices` lists your hardware
- [ ] `fwupdmgr refresh` updates metadata successfully
- [ ] Check for available updates: `fwupdmgr get-updates` (if any exist)
- [ ] **Note**: Most firmware updates require reboot to Windows or vendor tools on this hardware

### fstrim (SSD TRIM)
- [ ] TRIM is enabled: `systemctl status fstrim.timer` shows active (waiting)
- [ ] Check last run: `systemctl list-timers fstrim.timer`
- [ ] Verify SSD supports TRIM: `lsblk -D` (shows DISC-GRAN and DISC-MAX values)
- [ ] Manual test (optional): `sudo fstrim -v /` (shows bytes trimmed)

**If services fail**: Check logs with `journalctl -u <service-name>` and report issues.

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
sudo tar czf /persist/efi-backup-$(date +%Y%m%d).tar.gz -C /boot .

# Periodic verification (add to weekly cron or timer)
bootctl status  # Should show "Secure Boot: disabled" or "enabled" consistently
sbctl status    # Shows key enrollment status

# Check for EFI corruption signs
dmesg | grep -i efi | grep -i -E "(error|corrupt|fail)"
```
**Storage**: Keep `/persist/efi-backup-*.tar.gz` on external media, not just `@persist`.

### [FIXED] fstrim/discard Configuration
**Decision**: Option A implemented (periodic fstrim timer).  
**Rationale**: Safer for LUKS — no real-time info-leak side channels from discard.  
**Code**: `services.fstrim.enable = true;` in `base-desktop.nix`; `allowDiscards` removed from LUKS config.  
**Verification**: Check timer is active: `systemctl list-timers | grep fstrim`

### [FIXED] Sleep States (Suspend/Hibernate) Policy
**Decision**: Sleep states disabled via configurable `allowSleep` option.  
**Rationale**: 16GB RAM + 8GB swap = insufficient for hibernation; NVIDIA proprietary drivers often have suspend/resume issues; tmpfs+LUKS adds complexity.  
**Code**: `myOS.security.allowSleep` option (default: false), wired to `powerManagement.enable`.  
**Current**: Both daily and paranoid explicitly set `allowSleep = false`.  
**Verification**: `systemctl status systemd-hibernate.service` should show disabled state.  
**To enable** (test carefully): Set `myOS.security.allowSleep = true` in your profile and verify on your hardware.

### [TODO] doas/run0 vs sudo Analysis
**Status**: Deferred from wave one; revisit post-stability.  
**Research question**: Should sudo be replaced with `doas` (OpenBSD, ~500 lines) or `run0` (systemd/polkit)?

**Current**: sudo remains in place as conservative choice. It's battle-tested on NixOS, well-documented, and changing it adds risk without immediate security benefit for wave one.

**Arguments for doas**:
- Smaller attack surface (~500 lines vs sudo's 10k+)
- Simpler configuration syntax
- No CVE history comparable to sudo's complexity

**Arguments for run0**:
- Native systemd integration
- Polkit-based (graphical auth dialogs possible)
- No setuid binary (uses D-Bus activation)

**Arguments against switching**:
- sudo is standard on NixOS; community knowledge/tooling assumes it
- doas feature gap: no per-command env vars, limited logging
- run0: relatively new, less battle-tested in desktop scenarios
- Both require updating all documentation and muscle memory

**Post-stability task**: After system is stable, test doas or run0 in a VM/specialisation. Evaluate: (1) compatibility with existing workflows, (2) security benefit measurable vs placebo, (3) NixOS community direction. Only switch if benefit is clear and well-tested.

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

### [FIXED] Bootloader Recovery Documentation Enhancement
**Status**: Addressed - recovery procedures documented in RECOVERY.md
- "If Secure Boot breaks boot" section
- "If disabling Secure Boot still doesn't boot (Lanzaboote nuclear recovery)" section with full sbctl reset and systemd-boot fallback procedure
**Note**: Emergency ISO with pre-enrolled keys remains a potential future enhancement for advanced lockout scenarios.

### [FIXED] Bubblewrap GPU Passthrough Acknowledgment
**Risk**: `safe-firefox` uses `--dev-bind /dev/dri` which exposes GPU attack surface. GPU drivers have history of DMA attacks.  
**Fix**: Documentation updated to acknowledge this limitation.  
**Current claim**: "National-level" isolation is overstated for GPU-bound apps.  
**Actual isolation**: UID namespace + process namespace + FS isolation = strong, but GPU passthrough is a known escape vector (historical GPU driver bugs allow DMA attacks). Network namespace is NOT isolated for browsers.  
**Recommendation**: For maximum isolation of untrusted content, use VM isolation (`sandbox.vms`) instead of bubblewrap, or run `safe-firefox` on a system without GPU passthrough (software rendering).

### [TRIAL] Test Browser Without GPU Passthrough
**Purpose**: Evaluate usability of software rendering for maximum isolation.  
**Trade-off**: Removes GPU attack surface (DMA attacks) but significantly slower performance.
**Profile**: Test on **paranoid** — daily needs GPU acceleration for gaming/VR.

**Quick test (temporary):**
```bash
# Launch safe-firefox with GPU disabled (software rendering)
safe-firefox --safe-mode &
# Then in about:config set: layers.acceleration.disabled = true
```

**Persistent test (session-wide):**
```bash
# Create a wrapper script without /dev/dri bind
# Copy safe-firefox script, remove: --dev-bind /dev/dri /dev/dri
# Save as ~/bin/safe-firefox-software and use instead
```

**What to test:**
1. Video playback (YouTube, etc.) - expect higher CPU usage
2. Scrolling smoothness on complex pages
3. General responsiveness
4. Battery life (on laptops)

**Decision criteria:**
- If performance is acceptable: consider creating custom wrapper without GPU passthrough
- If unusable: stay with GPU passthrough and rely on VM isolation for untrusted content
- Critical: For high-risk content (untrusted PDFs, suspicious sites), prefer VM isolation regardless

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

### [TODO] Nix Trusted-Users Evaluation
**Risk**: Current configuration uses `trusted-users = ["root"]` (minimal safe default). This may cause friction for development workflows that frequently need privileged Nix operations.

**Current state**:
- `trusted-users` is hardcoded to `["root"]` in `modules/core/base-desktop.nix` for both profiles
- This is the minimal safe default recommended by upstream Nix security guidance
- Reduces attack surface by avoiding root-equivalent Nix privileges for users

**What works normally (no sudo needed)**:
- `nix shell` for development environments
- `nix build` for most packages
- `nix run` for running packages
- `nix search`, `nix info`, etc.
- `sudo` and `su` for system operations (unaffected by Nix trusted-users)

**What might need sudo occasionally**:
- Building packages that require privileged operations (rare for typical dev)
- Setting global Nix configuration via `nix.settings`
- Some binary cache operations
- Garbage collection as root

**Evaluation criteria**:
After using the system for your typical development workflow, evaluate:
1. Do you frequently need `sudo` for Nix operations?
2. Does the current setting cause significant friction?
3. Are you comfortable with the security tradeoff of adding your user to `trusted-users`?

**If you need to add your user**:
```bash
# Edit modules/core/base-desktop.nix:
nix.settings = {
  ...
  trusted-users = [ "root" "player" ];  # Add your user
  ...
}

# Rebuild
nixos-rebuild switch --flake /etc/nixos#nixos
```

**Security implications of adding your user**:
- Your user gets root-equivalent Nix privileges
- Can build as root (bypass sandbox restrictions)
- Can set configuration options
- Can perform garbage collection as root
- This is a deliberate security tradeoff for workflow convenience

**Decision**:
- If minimal friction: Keep current `["root"]` setting (safer)
- If significant friction: Add your user, document the decision, understand the tradeoff
- Consider using `sudo nix ...` for specific operations instead of adding your user globally

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

## 20. PAM profile-binding (EXPERIMENTAL - opt-in only)

**WARNING**: This is a high-risk PAM modification. It writes directly to `security.pam.services.*.text`, replacing the entire PAM service file. This bypasses NixOS's default PAM stack generation and can cause authentication lockouts if misconfigured.

**Default**: **DISABLED** in both profiles. Only enable after post-stability testing.

### What it does
Enforces user/profile binding at the PAM level:
- Daily profile: Only `player` can login/sudo/su
- Paranoid profile: Only `ghost` can login/sudo/su
- Cross-profile user switching is blocked (cannot `su` from daily to ghost or vice versa)

### Pre-enable verification
Test thoroughly before enabling:
```bash
# Verify current PAM works for both users
sudo pamtester sddm player authenticate
sudo pamtester login ghost authenticate
sudo pamtester sudo player authenticate
sudo pamtester su player authenticate

# Check systemd services
systemctl status systemd-logind
```

### Enable (both profiles)
Edit your profile (`profiles/daily.nix` or `profiles/paranoid.nix`):
```nix
myOS.security.pamProfileBinding.enable = true;  # or lib.mkForce true for paranoid
```

Rebuild and test immediately:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# CRITICAL: Test before closing this terminal
# Open a NEW terminal/window and verify:
pamtester sddm player authenticate  # Should succeed on daily
pamtester sudo player authenticate   # Should succeed

# Test wrong-user blocking (should fail):
# (On daily) sudo pamtester sddm ghost authenticate  # Should fail
```

### Recovery if locked out
If authentication breaks:
1. Boot to recovery mode or NixOS installer USB
2. Mount your system: `nixos-enter` or manual mount
3. Edit `/etc/nixos/profiles/daily.nix` (or paranoid.nix):
   ```nix
   myOS.security.pamProfileBinding.enable = false;
   ```
4. Rebuild: `nixos-rebuild switch --flake /etc/nixos#nixos`
5. Alternative emergency fix: Edit `/etc/pam.d/sddm`, `/etc/pam.d/login`, etc. to remove the profile-binding line

### Implementation notes
- Uses `lib.mkDefault` and `lib.mkOrder 100` for non-destructive insertion
- Uses `requisite` (not `required`) for fail-fast behavior
- Root access preserved as emergency fallback in the script
- Future: Consider migrating to `security.pam.services.<name>.rules` API (experimental in nixpkgs)

---

**Summary**: 4 items fixed (LUKS header backup, EFI backup, bubblewrap acknowledgment, SSH rotation); 7 items require your explicit decision (added PAM risk documentation).
