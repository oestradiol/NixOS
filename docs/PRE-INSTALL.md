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
- `modules/security/networking.nix` — Mullvad app mode networking, nftables fallback for app mode
- `modules/security/wireguard.nix` — Self-owned WireGuard stack for paranoid (single-source-of-truth config + firewall)
- `modules/security/browser.nix` — Firefox policies or sandboxed browser wrappers (UID 100000, bubblewrap)
  - When `sandbox.browsers = false` (daily): Base Firefox with 60+ hardening prefs (all telemetry disabled, safe browsing local-only, prefetch blocked, HTTPS-only, dFPI, ETP strict, OCSP hard-fail, container tabs, shutdown sanitizing, FPP fingerprinting protection per arkenfox v140+)
  - When `sandbox.browsers = true` (paranoid): Base Firefox disabled, only sandboxed wrappers available (safe-firefox with full hardened user.js including RFP, safe-tor-browser, safe-mullvad-browser)
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
- `modules/security/governance.nix` — 30 build-time assertions
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
| UID/GID mismatch on paranoid home | `hardware-target.nix` derives from `config.users.users."ghost"` | Verify `ghost` user UID/GID in `modules/core/users.nix` match tmpfs mount options |
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

### Networking / VPN architecture

**Two mutually exclusive modes:**

| Mode | Profile | Module | Authority |
|------|---------|--------|-----------|
| Mullvad app | daily | `networking.nix` | Mullvad daemon + optional nftables fallback |
| Self-owned WireGuard | paranoid | `wireguard.nix` | NixOS (config generates firewall) |

#### Self-owned WireGuard (paranoid) — RECOMMENDED

| Claim | Verification | Status |
|-------|--------------|--------|
| Single source of truth | `wireguard.nix`: WireGuard config generates firewall rules | ✅ VERIFIED |
| Fixed interface name | `wg-mullvad` hardcoded, used in both WG config and firewall | ✅ VERIFIED |
| Killswitch: default-deny output | Only DHCP/NDP bootstrap, DNS through tunnel, WG handshake, tunnel traffic | ✅ VERIFIED |
| No Mullvad app | `services.mullvad-vpn.enable = false` when WG mode active | ✅ VERIFIED |
| DNS through tunnel only | `oifname "wg-mullvad" udp/tcp dport 53 accept` | ✅ VERIFIED |
| No NixOS firewall conflict | `networking.firewall.enable = false` in WG mode | ✅ VERIFIED |

**Required setup**: See Section 15 below for WireGuard config generation.

#### Mullvad app mode (daily)

**Architecture**: Mullvad app manages its own firewall state. No nftables killswitch from this repo.

**Killswitch**: Use Mullvad's built-in `mullvad lockdown-mode set on` for enforcement.

**Known leakage**: Brief DNS queries at boot before tunnel establishment (unavoidable - must resolve VPN endpoint).

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
| 30 assertions | `modules/security/governance.nix` lines 7-140 | ✅ VERIFIED |
| Paranoid requires sandboxed browsers | Lines 17-18 | ✅ VERIFIED |
| Paranoid requires wireguardMullvad | Lines 21-26 | ✅ VERIFIED |
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
| Lanzaboote integration | `secure-boot.nix:6-11` | ✅ VERIFIED |
| TPM requires systemd initrd | `secure-boot.nix:13-16` | ✅ VERIFIED |
| Staged (disabled by default) | `hosts/nixos/default.nix:38-39` | ✅ VERIFIED |

---

## Governance self-check

1. Is this claim listed in `PROJECT-STATE.md`?
2. Is the code file in the code map above?
3. Did I verify build/runtime, or am I trusting an inspected file?

---

---

## Section 15 — WireGuard Configuration (paranoid profile)

**Purpose**: Configure self-owned WireGuard tunnel to Mullvad servers. This replaces the Mullvad app on paranoid with a deterministic, auditable NixOS-native stack.

**Memory anchor**: Mullvad as provider, NixOS as authority.

### 15.1 Generate WireGuard keys

On a trusted machine with `wg` (wireguard-tools):

```bash
# Generate private key
wg genkey | tee mullvad-private.key | wg pubkey > mullvad-public.key

# Optional: generate preshared key for post-quantum resistance
wg genpsk > mullvad-preshared.key
```

### 15.2 Get Mullvad server configuration

1. Log in to https://mullvad.net/en/account/
2. Go to "WireGuard configuration" or use the API
3. Select a server (e.g., `us-nyc-wg-001`)
4. Note these values:
   - **Server public key**: The WireGuard public key of the Mullvad server
   - **Server endpoint**: Hostname or IP with port (e.g., `us-nyc-wg-001.mullvad.net:51820`)
   - **Your assigned IP**: The tunnel IP Mullvad assigns you (e.g., `10.64.123.45/32`)
   - **DNS server**: Usually `10.64.0.1` (Mullvad's ad-blocking DNS)

Alternative: Use Mullvad's CLI config generator:
```bash
# Install mullvad-vpn temporarily on another machine
mullvad relay set tunnel-protocol wireguard
mullvad relay set location us nyc  # or your preferred location
mullvad connect
# Then extract the config from the app or generate via web
```

### 15.3 Create secrets file with agenix

Create `secrets/wireguard.nix` (this is a template - never commit real keys):

```nix
{ config, pkgs, ... }:
{
  # Reference these in your host config
  # The actual encrypted secrets go in secrets/wireguard-*.age
  age.secrets.wg-private-key.file = ../secrets/wireguard-private.age;
  age.secrets.wg-preshared-key.file = ../secrets/wireguard-preshared.age;
}
```

Encrypt your keys:

```bash
# Get your system's public age key
agenix-keygen  # or cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

# Encrypt the private key (replace with your recipient key)
age -r age1yourpublickey... -o secrets/wireguard-private.age mullvad-private.key

# Encrypt preshared key if generated
age -r age1yourpublickey... -o secrets/wireguard-preshared.age mullvad-preshared.key

# Remove plaintext files securely
shred -u mullvad-private.key mullvad-public.key mullvad-preshared.key
```

### 15.4 Configure the paranoid profile

Edit `profiles/paranoid.nix` and uncomment/complete the WireGuard options:

```nix
myOS.security = {
  # ... other options ...

  wireguardMullvad = {
    enable = lib.mkForce true;
    privateKeyFile = config.age.secrets.wg-private-key.path;
    presharedKeyFile = config.age.secrets.wg-preshared-key.path;  # optional
    address = "10.64.123.45/32";  # Your Mullvad-assigned tunnel IP
    endpoint = "us-nyc-wg-001.mullvad.net:51820";  # Your chosen server
    serverPublicKey = "<server-public-key-here>";  # From Mullvad config
    dns = "10.64.0.1";  # Mullvad DNS through tunnel
  };
};
```

### 15.5 Verify the configuration

Build and check:

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
# Should succeed with assertions passing

# Verify the nftables ruleset includes your endpoint
nix build .#nixosConfigurations.nixos.config.networking.nftables.ruleset
```

### 15.6 Post-install verification

After first boot into paranoid profile:

```bash
# Check WireGuard interface is up
ip link show wg-mullvad

# Check tunnel is established (should show handshake)
sudo wg show wg-mullvad

# Verify routing (default should be via wg-mullvad)
ip route | grep default

# Test for DNS leaks (should show Mullvad DNS, not ISP)
dig +short whoami.mullvad.net

# Test for IP leaks (should show Mullvad exit IP)
curl https://am.i.mullvad.net/connected
```

### 15.7 Architecture verification

Confirm the security property holds:

```bash
# Check nftables is active and policy is default-deny
sudo nft list table inet filter
# Should see: chain output { type filter hook output priority filter; policy drop; ... }

# Check that only wg-mullvad can egress (no leaks)
# Temporarily stop the WG interface - all outbound should fail
sudo systemctl stop wg-quick-wg-mullvad
curl https://example.com  # Should hang/fail
sudo systemctl start wg-quick-wg-mullvad
```

---

**Next**: After install completes, proceed to [`TEST-PLAN.md`](./TEST-PLAN.md) for runtime verification.
