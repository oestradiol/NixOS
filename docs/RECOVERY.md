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

## If Secure Boot breaks boot
1. disable Secure Boot in firmware
2. boot the previous known-good entry or installer
3. inspect `/var/lib/secureboot`
4. rebuild and re-enroll keys only after identifying the issue

## If TPM unlock breaks
1. use recovery passphrase
2. boot normally
3. inspect measured boot / changed PCR assumptions
4. re-enroll TPM only after a stable generation is active

## If the paranoid profile blocks too much network
1. boot default daily profile
2. edit the Mullvad/nftables policy
3. rebuild
4. only retest paranoid after daily is healthy again
