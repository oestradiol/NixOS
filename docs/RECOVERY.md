# RECOVERY

## Golden rules
- keep the LUKS recovery passphrase
- keep a recent exported copy of this repo outside the machine
- keep a bootable NixOS installer USB
- do not enable Secure Boot until one clean encrypted boot works

## If the new system does not boot
1. boot installer USB
2. unlock `NIXCRYPT`
3. mount `/mnt` exactly as in the install guide
4. `nixos-enter` or chroot as needed
5. roll back with `nixos-rebuild --rollback` if appropriate
6. check `journalctl -b -1 -p err` for errors

## If Secure Boot breaks boot
1. disable Secure Boot in firmware
2. boot the previous known-good entry or installer
3. inspect `/var/lib/secureboot`
4. rebuild and re-enroll keys only after identifying the issue
5. check `sbctl status` and `sbctl verify` for signature issues

## If disabling Secure Boot still doesn't boot (Lanzaboote nuclear recovery)
**Symptom**: Even with Secure Boot disabled in firmware, system won't boot.  
**Cause**: Lanzaboote may have corrupted boot entries or ESP contents.
```bash
# 1. Boot NixOS installer USB
# 2. Unlock and mount everything as in INSTALL-GUIDE.md Phase 2-3
sudo cryptsetup open /dev/disk/by-partlabel/NIXCRYPT cryptroot
sudo mount /dev/mapper/cryptroot /mnt
sudo mount /dev/disk/by-partlabel/NIXBOOT /mnt/boot
for subvol in nix persist var/log; do sudo mount /mnt/$subvol; done
sudo nixos-enter

# 3. Inside chroot, check signature status
sbctl verify  # Shows which files have signature issues
sbctl status    # Shows enrollment state

# 4. Nuclear option: reset signature database
sbctl reset     # Clears all custom keys (you'll need to re-enroll)

# 5. If Lanzaboote itself is broken, temporarily switch to standard systemd-boot
# Edit /etc/nixos/hosts/nixos/default.nix:
#   boot.loader.systemd-boot.enable = true;
#   boot.lanzaboote.enable = false;
#   myOS.security.secureBoot.enable = false;
nixos-rebuild switch

# 6. Reboot - should boot with standard systemd-boot (no Secure Boot)
# 7. Once stable, you can re-enable Lanzaboote if desired
```
**Prevention**: Keep `/persist/efi-backup-*.tar.gz` on external media before enabling Secure Boot.

## If TPM unlock breaks
1. use recovery passphrase
2. boot normally
3. inspect measured boot / changed PCR assumptions
4. re-enroll TPM only after a stable generation is active
5. `sudo systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT` to check slots

## If the paranoid profile blocks too much network
1. boot default daily profile
2. edit the Mullvad/nftables policy in `modules/security/networking.nix`
3. check `sudo nft list ruleset` to identify blocking rule
4. rebuild and retest paranoid after daily is healthy again

## If NVIDIA/Wayland breaks after update
1. boot into previous generation: `nixos-rebuild --rollback`
2. check NVIDIA driver version: `nvidia-smi`
3. check kernel logs: `dmesg | grep -i nvidia`
4. consider pinning kernel or driver version if this recurs
5. report issue to NVIDIA or NixOS channels

## If USB authorization blocks peripherals (paranoid)
1. boot daily profile to confirm hardware works
2. check `dmesg | grep -i usb` for authorization failures
3. if internal hub blocked, add device ID to allowlist in kernel params
4. temporarily disable `usbRestrict` in paranoid profile if needed

## If gaming performance regresses
1. check `swappiness` value: `sysctl vm.swappiness` (daily should be 150, paranoid 180)
2. check `ptrace_scope`: `sysctl kernel.yama.ptrace_scope` (daily should be 1)
3. disable AppArmor temporarily: `security.apparmor.enable = false` in daily profile
4. disable `init_on_alloc`: `kernelHardening.initOnAlloc = false` in daily profile
5. benchmark each change to identify the culprit

## If impermanence causes app issues
1. check app writes to non-persisted paths
2. add paths to persistence allowlist in `modules/security/impermanence.nix`
3. check `findmnt -R /` to verify mounts
4. test with a file in persisted vs non-persisted location

## If governance assertions fail at build
1. read the assertion message carefully
2. check the option in `modules/core/options.nix`
3. check the profile setting in `profiles/daily.nix` or `profiles/paranoid.nix`
4. update either the option default or the profile setting
5. ensure `PROJECT-STATE.md` reflects the intended behavior
