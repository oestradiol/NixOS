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

## Governance self-check

1. Is this claim listed in `PROJECT-STATE.md`?
2. Is the code file in the code map above?
3. Did I verify build/runtime, or am I trusting an inspected file?

---

**Next**: After install completes, proceed to [`TEST-PLAN.md`](./TEST-PLAN.md) for runtime verification.
