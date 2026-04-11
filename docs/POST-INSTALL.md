# POST-INSTALL

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
1. Edit `hosts/nixos/default.nix`: set `myOS.security.secureBoot.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
3. `sudo sbctl create-keys`
4. `sudo sbctl enroll-keys --microsoft`
5. Enable Secure Boot in firmware
6. Reboot and verify: `bootctl status`, `sbctl status`

## 5. TPM2 LUKS enrollment
Keep the recovery passphrase forever.
1. Edit `hosts/nixos/default.nix`: set `myOS.security.tpm.enable = true;`
2. `sudo nixos-rebuild switch --flake /etc/nixos#nixos` (this enables systemd initrd)
3. Identify the correct LUKS device (`/dev/disk/by-partlabel/NIXCRYPT`)
4. Enroll TPM2: `sudo systemd-cryptenroll /dev/disk/by-partlabel/NIXCRYPT --tpm2-device=auto --tpm2-pcrs=0+7`
5. Reboot-test twice
6. If TPM measurement changes break unlock, use recovery passphrase and re-enroll

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

## 9. Hardening runtime verification
Follow `docs/AUDIT.md` Phase 5 to verify:
- sysctl values are applied
- root is locked
- kernel modules are blacklisted
- systemd service hardening is active
- USB authorization is correct on paranoid

## 10. Manual follow-ups
- Validate Mullvad interface names match nftables rules (adjust `vpnIfaces` in networking.nix if needed)
- Create real `.age` files under `secrets/`
- Verify USB peripherals work on paranoid (authorized_default=2 allows internal hub devices)
- Enable Bluetooth controllers: set `myOS.gaming.controllers.enable = true` in your profile
- Run `lynis audit system` and address findings
- Only then experiment with `hardenedMemory.enable = true`

## 11. Install Flatpak applications (daily profile)
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

## 12. Use sandboxed applications
For apps not available as Flatpak, use the bubblewrap wrappers:
- `safe-vrcx` — VRCX with UID isolation (daily profile)
- `safe-windsurf` — Windsurf with UID isolation (daily profile)

These wrappers provide UID isolation (100000:100000 unmapped from host), network namespace isolation, and minimal filesystem access.

## 13. Monitor these hardening knobs on daily
All negligible-impact hardening is kept enabled on daily by decision. If specific issues arise, disable via `myOS.security.*` in `profiles/daily.nix`:
- **AppArmor** (`apparmor = false`) — if specific apps fail with permission errors
- **init_on_alloc** (`kernelHardening.initOnAlloc = false`) — if allocation-heavy workloads show measurable regression
- **slab_nomerge** (`kernelHardening.slabNomerge = false`) — if RAM is critically tight
- **Module blacklist** (`kernelHardening.moduleBlacklist = false`) — if you need dccp/sctp/firewire for some reason
- **Root lock** (`lockRoot = false`) — only if you need direct root login (not recommended)

## Deferred items
- Full SUID/capability pruning program
- NTS time sync replacement (knob not yet implemented)
- Full hardened compilation-flag policy
- Dedicated entropy-hardening component
- Full nix-mineral diff
