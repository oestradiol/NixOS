# INSTALL GUIDE

Installation guide for the NixOS hardening framework.

## Prerequisites

### 1. Understand What You're Installing

This is a **NixOS hardening framework** — a library of reusable modules (`nixosModules.*`) plus reference templates. It provides:

- **40 `nixosModules.*` exports** — Cherry-pick hardening features or use pre-built profiles
- **Storage management** — Framework-owned LUKS/Btrfs/tmpfs layout via `myOS.storage.*`
- **Orthogonal axes** — System posture (profile) is separate from user identity

**Not a distribution** — you remain in control. The framework provides hardening substrate; your template provides the specific configuration.

### 2. Choose Your Template

| Template | Profile | Best For | Complexity |
|----------|---------|----------|------------|
| [`workstation`](../../templates/workstation/) | `daily` only | Secure workstation with gaming/social | Low |
| [`default`](../../templates/default/) | `paranoid` + `daily` | Maximum privacy separation | Medium |

**Workstation template** (`templates/workstation/`):
- Single user on `daily` profile
- Persistent home, gaming, Flatpak, Steam
- Normal Firefox (enterprise policy managed)
- Full hardening substrate without profile switching

**Default template** (`templates/default/`):
- Two users: daily (`player`) + paranoid (`ghost`)
- Cross-profile mount isolation (users cannot access each other's homes)
- Paranoid: tmpfs home, sandboxed browsers, audit subsystem
- Boot-time profile selection via specialisation

### 3. Choose Your Installation Method

**Method A: Template Quickstart (Recommended)**
```bash
# From NixOS installer, fetch template
nix flake init -t github:oestradiol/NixOS#workstation  # or #default
# Edit flake.nix, then install
```

**Method B: Manual Clone**
```bash
# Clone framework repo
git clone https://github.com/oestradiol/NixOS.git
cd NixOS/templates/workstation  # or default
# Edit config, then install
```

**Method C: Cherry-Pick (Existing Flake)**
```nix
# In your existing flake.nix
inputs.hardening.url = "github:oestradiol/NixOS";
# Import specific nixosModules.* in your configuration
```

### 4. Storage Requirements

Supported topology:
- **EFI partition**: 512MB+ (label `NIXBOOT` by default)
- **LUKS2 root partition**: Remainder of disk (partlabel `NIXCRYPT` by default)
- **Btrfs subvolumes**: `@nix`, `@persist`, `@log`, optional `@swap`
- **tmpfs root**: `/` lives in RAM (capped at 16GB, uses only what is held)

Options:
- **Keep defaults**: Zero storage configuration needed
- **Custom labels**: Override via `myOS.storage.*` in `local.nix`
- **Custom layout**: Set `myOS.storage.enable = false`, provide your own `fileSystems`

### 5. User Model Planning

Users are declared via `myOS.users.<name>`:
- `activeOnProfiles`: Which profiles unlock this user
- `home.persistent`: Btrfs-backed (true) or tmpfs with allowlist (false)
- `allowWheel`: Whether user can sudo

Reference patterns:
- **Daily-style**: `home.persistent = true`, `allowWheel = true`
- **Paranoid-style**: `home.persistent = false`, `allowWheel = false`

Template-specific: See your template's `accounts/` directory for example user definitions.

### 6. Secrets Planning

| Secret | Location | When Needed |
|--------|----------|-------------|
| User passwords | `/persist/secrets/<user>-password.hash` | Always (declarative via `hashedPasswordFile`) |
| Mullvad credentials | Mullvad app login | If using Mullvad VPN |
| Agenix secrets | `*.age` files + host key | If enabling agenix features |
| WireGuard keys | `/persist/secrets/` | If enabling self-owned WireGuard path |

The install script discovers `hashedPasswordFile` paths and prompts for password entry.

### 7. Current Profile Features

**Daily profile:**
- `sandbox.apps = true`, `sandbox.browsers = false`, `sandbox.vms = false`
- Enterprise-policy Firefox (normal Firefox, not arkenfox)
- Gaming, Steam, VR support, Flatpak

**Paranoid profile:**
- `sandbox.apps = false`, `sandbox.browsers = true`, `sandbox.vms = true`
- `safe-firefox` with arkenfox baseline + wrapper
- Audit subsystem, AppArmor framework
- VM tooling for escalation path

**Both profiles:**
- Mullvad app mode (if enabled)
- Kernel hardening (`slab_nomerge`, `init_on_alloc`, `pti=on`, etc.)
- LUKS encryption, tmpfs root, impermanence

### 8. Staged Features (Not Baseline)

These require explicit enable after stable baseline:
- Secure Boot via Lanzaboote
- TPM-bound unlock
- Self-owned WireGuard path (requires pinned `IP:port` endpoint)
- Custom audit rules
- Custom AppArmor profile library

### 9. Red Flags Before Installing

Do not proceed if:
- [ ] You haven't backed up the target disk
- [ ] You're not willing to wipe the disk completely
- [ ] You haven't decided how user passwords will be set
- [ ] You plan to enable self-owned WireGuard but lack a pinned endpoint `IP:port`
- [ ] You're treating post-stability items as blocking for first baseline

## Installation Steps

### Method 1: Guided Install Script (Recommended)

The `rebuild-install.sh` script handles the entire install process:

```bash
# From NixOS installer ISO, fetch the script
curl -L -o rebuild-install.sh https://raw.githubusercontent.com/oestradiol/NixOS/main/scripts/rebuild-install.sh
chmod +x rebuild-install.sh
sudo ./rebuild-install.sh
```

Or if you already have the repo:
```bash
sudo ./scripts/rebuild-install.sh [path/to/your/flake]
```

#### Script Phases

The script runs through these phases interactively:

**Phase 0 — Flake Selection**
- Prompts for target flake path/URL (guesses from repo if available)
- Lists available framework templates (`templates/workstation`, `templates/default`)
- Prompts for template selection
- Lists available `nixosConfigurations` in your flake
- Prompts for configuration attribute (e.g., `nixos`, `workstation`)

**Phase 1 — Disk Selection**
- Shows available disks (`lsblk`)
- Guesses EFI and encrypted root partitions (prefers `nvme0n1p1`/`p5` if present)
- Prompts for confirmation:
  - EFI partition device (e.g., `/dev/nvme0n1p1`)
  - Encrypted root partition (e.g., `/dev/nvme0n1p5`)
- Requires typing "REFORMAT" to confirm wipe

**Phase 2 — Formatting**
- Formats EFI partition as FAT32
- Runs `cryptsetup luksFormat` on root partition (you set passphrase)
- Opens LUKS container as `cryptroot`
- Creates Btrfs filesystem

**Phase 3 — Btrfs Subvolumes**
- Creates subvolumes: `@nix`, `@persist`, `@log`
- Creates swap subvolume if enabled (`@swap`)
- Creates per-user home subvolumes from `myOS.users.*` config

**Phase 4 — Mount Layout**
- Mounts tmpfs root (capped at 16GB)
- Mounts Btrfs subvolumes with `compress=zstd,noatime`
- Mounts EFI partition to `/boot`
- Creates swapfile if enabled
- Verifies all mount points

**Phase 5 — Staging**
- Copies flake source to `/mnt/etc/nixos`
- If using framework as flake input, vendors it to `.framework/hardening`
- Generates `hardware-target.nix` from `nixos-generate-config`
- Strips filesystem/swap config (framework owns storage)
- Offers nano review of generated hardware config

**Phase 6 — Passwords**
- Discovers `hashedPasswordFile` paths from config
- Prompts for each user's password interactively
- Writes hashed passwords to `/mnt/persist/secrets/`

**Phase 7 — Validation**
- Optionally runs `nix flake check`

**Phase 8 — Install**
- Runs `nixos-install --flake <path>#<config> --no-root-passwd`
- Installation is complete

### Method 2: Manual Install

If you prefer full control:

```bash
# 1. Partition and format manually
mkfs.fat -F 32 -n NIXBOOT /dev/nvme0n1p1
cryptsetup luksFormat --type luks2 /dev/nvme0n1p5
cryptsetup open /dev/nvme0n1p5 cryptroot
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# 2. Create and mount subvolumes
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persist
btrfs subvolume create /mnt/@log
umount /mnt

# 3. Mount target layout
mount -t tmpfs none /mnt -o mode=755,size=16G
mkdir -p /mnt/{boot,nix,var/log,etc,persist,home}
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@persist,compress=zstd,noatime /dev/mapper/cryptroot /mnt/persist
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
mount -t vfat /dev/nvme0n1p1 /mnt/boot
chmod 700 /mnt/persist
mkdir -p /mnt/persist/secrets /mnt/persist/home

# 4. Stage your flake
mkdir -p /mnt/etc/nixos
cp -r /path/to/your/flake/* /mnt/etc/nixos/

# 5. Generate hardware config
nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-target.nix

# 6. Write password hashes (if using declarative passwords)
mkpasswd --method=yescrypt > /mnt/persist/secrets/youruser-password.hash

# 7. Install
nixos-install --flake /mnt/etc/nixos#yourconfig --no-root-passwd
```

## Post-Install: First Boot

### Workstation Template Users

After reboot:
1. Log in as your configured user
2. Review `hardware-target.nix` for accuracy
3. Run: `sudo nixos-rebuild switch --flake /etc/nixos#workstation`

### Default Template Users

After reboot:
1. **Choose `daily` specialization** in boot menu for first validation
2. Log in as `player` (daily user)
3. Make canonical edits only:
   ```bash
   sudoedit /etc/nixos/templates/default/hosts/nixos/hardware-target.nix
   sudoedit /etc/nixos/templates/default/accounts/player.nix
   sudoedit /etc/nixos/templates/default/accounts/ghost.nix
   ```
4. Rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#nixos --specialisation daily`

The first boot goal is **not** "finish every hardening feature." The goal is:
- Make daily reachable and recoverable
- Make daily good enough to continue iteration safely

## After First Boot

1. Place any required secrets (Mullvad, agenix, etc.)
2. Run the test suite: `cd /etc/nixos && ./tests/run.sh --layer static`
3. Follow `TEST-PLAN.md` for runtime validation
4. Only move to paranoid validation after daily is usable

## Using the Install Script for Custom Templates

The script works with any flake that:
- Uses the framework's storage layout (`myOS.storage.enable = true`)
- Has tmpfs root enabled (`myOS.storage.rootTmpfs.enable = true`)
- Declares at least one `nixosConfiguration`

Example with a custom flake:
```bash
sudo ./rebuild-install.sh /path/to/your/custom/flake
# Select your template (if vendored)
# Select your nixosConfiguration
# Proceed through phases
```

The script discovers all storage and password settings from your evaluated config — no hardcoded assumptions about user names or partition layouts (beyond the EFI+LUKS+Btrfs topology).
