# Troubleshooting Guide

Diagnose and fix common issues with the hardened NixOS workstation.

## Emergency Recovery

If the system won't boot:
1. Boot previous generation from boot menu (hold Space during boot)
2. If that fails, boot NixOS installer ISO and mount manually
3. See `../pipeline/RECOVERY.md` for full rollback procedures

## Quick Diagnostics

### Check current profile and state

```bash
# Which profile is active?
cat /run/current-system/myOS-profile 2>/dev/null || echo "pre-profile system"

# List generations
sudo nix-env -p /nix/var/nix/profiles/system --list-generations

# Check for failed units
systemctl --failed
systemctl --user --failed
```

### Check profile-user binding

```bash
# Daily profile should show: daily user unlocked, paranoid user locked
# Paranoid profile should show: paranoid user unlocked, daily user locked

# Check user lock status
sudo passwd -S <username>

# Check home mount isolation
mountpoint /home/<daily-user>
mountpoint /home/<paranoid-user>
systemctl status profile-mount-invariants
```

### Check network and VPN

```bash
# Mullvad status (if using app mode)
mullvad status
mullvad connect

# DNS resolution
resolvectl status
resolvectl query example.com

# Firewall rules
sudo nft list ruleset
```

## Common Issues

### Build/Evaluation Failures

**Symptom**: `nixos-rebuild` fails with option or module errors

**Check**:
```bash
# Validate flake syntax
nix flake check --show-trace

# Check for missing secrets (agenix placeholders)
grep -r "age.secrets" /etc/nixos/ 2>/dev/null || true
```

**Fix**:
- Missing `*.local.nix` files: Copy from `.example` templates
- Syntax errors: Run `nix flake check` for detailed trace
- Secret placeholders: Either populate secrets or disable the feature

### Profile Switch Problems

**Symptom**: `flake-switch` activates wrong profile or fails

**Check**:
```bash
# Verify alias behavior
type flake-switch
cat /run/current-system/specialisation/daily 2>/dev/null && echo "daily active" || echo "default (paranoid) active"

# Check switch.log for history
sudo tail -20 /etc/nixos/switch.log 2>/dev/null || echo "no switch.log yet"
```

**Fix**:
```bash
# Explicit switch to daily
sudo nixos-rebuild switch --flake /etc/nixos#nixos --specialisation daily

# Explicit switch to paranoid (default)
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### Desktop/Session Issues

**Symptom**: Greetd doesn't appear, login loop, or Plasma crashes

**Check**:
```bash
# Greetd status
systemctl status greetd
journalctl -u greetd -b

# Display manager logs
journalctl -b | grep -i "greetd\|regreet\|wayland"

# GPU driver status (NVIDIA)
nvidia-smi
lsmod | grep nvidia
```

**Fix**:
- Greetd fails: Check `hardware-target.nix` GPU settings
- Login loop: Check user password hash file exists (for declarative passwords)
- Plasma crashes: Try booting previous generation

### Browser Wrapper Failures

**Symptom**: `safe-firefox`, `safe-tor-browser`, or `safe-mullvad-browser` won't launch

**Check**:
```bash
# Run from terminal to see errors
safe-firefox 2>&1 | head -20

# Check wrapper binary exists
which safe-firefox
ls -la /run/current-system/sw/bin/safe-firefox

# Check persisted state location
ls -la ~/.mozilla/safe-firefox/ 2>/dev/null || echo "no safe-firefox state yet"
```

**Common causes**:
- GPU unavailable in wrapper: Check `myOS.security.sandbox.browsers.gpu` setting
- Wayland/X11 mismatch: Check `XDG_SESSION_TYPE`
- Missing `/etc` allowlist entries: See `modules/security/browser.nix`

**Fix**:
```bash
# Run with debug output
safe-firefox --verbose 2>&1 | tee /tmp/browser-debug.log

# Check if unwrapped browser works (paranoid profile)
firefox  # This is the normal Firefox, not safe-firefox
```

### Audio Issues

**Symptom**: No sound or microphone not working

**Check**:
```bash
# PipeWire status
systemctl --user status pipewire wireplumber
pactl info
pactl list | grep -A5 "Name:"

# Check fcitx5 (input method)
systemctl --user status fcitx5
```

**Fix**:
```bash
# Restart PipeWire
systemctl --user restart pipewire wireplumber

# Check alsamixer for muted channels
alsamixer
```

### Gaming Issues (Daily Profile)

**Symptom**: Steam won't launch, games crash, or controller not detected

**Check**:
```bash
# Steam status
systemctl --user status steam
which steam

# Controller modules (daily profile)
lsmod | grep -E "xpad|xpadneo|hid_nintendo"

# Gamescope availability
which gamescope
gamescope --help 2>&1 | head -5
```

**Fix**:
```bash
# Ensure on daily profile
cat /run/current-system/myOS-profile  # should say "daily"

# Restart Steam
systemctl --user restart steam

# Check 32-bit libraries are present
file /run/current-system/sw/bin/steam
```

### Persistence/Impermanence Issues

**Symptom**: Settings don't persist across reboots

**Check**:
```bash
# Check impermanence mounts
mount | grep impermanence
ls -la /persist/

# Check machine-id persistence
cat /etc/machine-id
cat /persist/etc/machine-id 2>/dev/null || echo "no persisted machine-id"

# Check user home type (daily = Btrfs, paranoid = tmpfs)
df -h /home/<username>
mountpoint /home/<username>
```

**Fix**:
- Impermanence not mounted: Check `myOS.storage.*` config matches actual partitions
- Wrong machine-id: Check `/persist/etc/machine-id` exists and is bind-mounted
- Missing persist paths: Add to `myOS.users.<name>.home.persistDirs` or `home.persistFiles`

### Flatpak App Issues

**Symptom**: Flatpak apps won't install or launch

**Check**:
```bash
# Flathub remote
flatpak remotes

# Portal status
systemctl --user status xdg-desktop-portal*

# Specific app logs
flatpak run <app-id> 2>&1 | head -20
```

**Fix**:
```bash
# Re-add Flathub if missing
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Update Flatpak cache
flatpak update

# Check permissions
flatpak info --show-permissions <app-id>
```

### VM Tooling Issues (Paranoid Profile)

**Symptom**: `repo-vm-class` fails or VMs won't start

**Check**:
```bash
# Libvirtd status
systemctl status libvirtd

# VM class help
repo-vm-class help

# Network status
virsh net-list --all

# Check repo networks exist
virsh net-dumpxml repo-nat
virsh net-dumpxml repo-isolated
```

**Fix**:
```bash
# Start libvirtd if not running
sudo systemctl start libvirtd

# Define networks if missing
# (See modules/security/vm-tooling.nix for network definitions)

# Check user is in libvirtd group
groups | grep libvirtd
```

### Scanner/Integrity Issues

**Symptom**: ClamAV or AIDE warnings

**Check**:
```bash
# ClamAV status
systemctl status clamav-freshclam
systemctl list-timers | grep clamav
freshclam --version

# AIDE status (if enabled)
systemctl status aide
cat /etc/aide.conf 2>/dev/null | head -20
```

**Fix**:
```bash
# Update ClamAV signatures manually
sudo freshclam

# Run scans manually
sudo systemctl start clamav-impermanence-scan
sudo systemctl start clamav-deep-scan

# Initialize AIDE (first time only)
sudo aide --init
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

## Debug Mode

For development/debugging only (never on stable systems):

```nix
# In host config or local.nix
myOS.debug.enable = true;
myOS.debug.crossProfileLogin.enable = true;  # Allow any user on any profile
myOS.debug.paranoidWheel.enable = true;      # Add wheel to paranoid users
```

**Warning**: Debug mode prints warnings on every rebuild. Disable for stable systems.

## Getting Help

1. Check `../maps/AUDIT-STATUS.md` for known pending validation
2. Check `../pipeline/POST-STABILITY.md` for deferred features
3. Run test suite: `../tests/run.sh --layer static` (safe) or `--layer runtime` (on booted system)
4. Review relevant module source in `../../modules/`

## Debug Information to Collect

When reporting issues, include:

```bash
# System state
nixos-version
cat /run/current-system/myOS-profile 2>/dev/null || echo "no profile marker"

# Failed units
systemctl --failed --no-pager

# Recent errors
journalctl -b -p 3 --no-pager | tail -30

# Build attempt
sudo nixos-rebuild switch --flake /etc/nixos#nixos --show-trace 2>&1 | tail -50
```
