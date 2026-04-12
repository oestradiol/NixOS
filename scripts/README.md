# Scripts

Helper scripts for installation, audit, and post-install hardening.

All scripts use `set -euo pipefail` for safety. Review before running.

## Script Inventory

| Script | Purpose | When to Run | Risk Level |
|--------|---------|-------------|------------|
| `install-nvme-rebuild.sh` | Destructive disk partitioning for NVMe install | Before first install | **DESTRUCTIVE** - wipes entire disk |
| `post-install-secureboot-tpm.sh` | Secure Boot key enrollment and TPM setup | After first successful encrypted boot | Medium - modifies firmware/boot chain |
| `audit-tutorial.sh` | Static checks and audit guidance | Any time (read-only) | None |

## Detailed Usage

### install-nvme-rebuild.sh

**WARNING**: This script DESTROYS all data on the target disk.

```bash
# Default: /dev/nvme0n1
sudo ./scripts/install-nvme-rebuild.sh

# Custom disk:
sudo ./scripts/install-nvme-rebuild.sh /dev/nvme1n1
```

**What it does:**
1. Wipes disk with `sgdisk --zap-all`
2. Creates GPT layout: 512MiB EFI (NIXBOOT), rest LUKS (NIXCRYPT)
3. Formats EFI as FAT32
4. Sets up LUKS2 encryption
5. Creates Btrfs subvolumes: @nix, @persist, @log, @home-daily, @home-paranoid
6. Mounts tmpfs root and all subvolumes to `/mnt`

**After running:**
- Copy this repo to `/mnt/etc/nixos`
- Run `nixos-install --flake /mnt/etc/nixos#nixos`

### post-install-secureboot-tpm.sh

Run after first successful encrypted boot with working daily profile.

**Prerequisite (MUST do first):**
1. Edit `hosts/nixos/default.nix`: set `myOS.security.secureBoot.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
3. Verify system still boots normally

**Then run:**
```bash
sudo ./scripts/post-install-secureboot-tpm.sh
```

**What the script does:**
1. Creates Secure Boot keys (`sbctl create-keys`)
2. Enrolls keys with Microsoft CA (`sbctl enroll-keys --microsoft`)
3. Provides commented TPM enrollment example

**Final steps (manual):**
1. Reboot into firmware setup mode
2. Enable Secure Boot in firmware
3. Reboot and verify: `bootctl status`, `sbctl status`

**Before running:**
- Review `docs/POST-STABILITY.md` Section 4 (Secure Boot) and Section 5 (TPM)
- Ensure daily profile boots successfully
- Back up current working configuration

### audit-tutorial.sh

Read-only audit and verification script.

```bash
./scripts/audit-tutorial.sh
```

**What it does:**
1. Static repo checks (flake show, flake check, build tests)
2. Verifies canonical surfaces exist
3. Checks persistence configuration
4. Lists Secure Boot/TPM surface references
5. Lists networking/browser surface references
6. Prints runtime checks to perform after install

**Safe to run at any time.** Does not modify system state.

## Risk Summary

| Action | Data Loss | System Changes | Reversibility |
|--------|-----------|----------------|---------------|
| `install-nvme-rebuild.sh` | **Total disk wipe** | Partition table, LUKS header, filesystems | Irreversible |
| `post-install-secureboot-tpm.sh` | None | Firmware PK/KEK/db, boot chain | Reversible with firmware reset |
| `audit-tutorial.sh` | None | None | N/A (read-only) |

## Safety Checklist

Before running `install-nvme-rebuild.sh`:
- [ ] Backup all important data
- [ ] Verify target disk (`lsblk`)
- [ ] Confirm this is the reinstall target, not current running system
- [ ] Have NixOS installer USB ready

Before running `post-install-secureboot-tpm.sh`:
- [ ] Daily profile boots successfully
- [ ] LUKS passphrase recovery method tested
- [ ] Firmware setup mode access confirmed
