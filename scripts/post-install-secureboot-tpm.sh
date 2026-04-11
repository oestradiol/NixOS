#!/usr/bin/env bash
set -euo pipefail

# Run only after the first successful normal encrypted boot.
# Review docs/POST-STABILITY.md Section 4 (Secure Boot) and Section 5 (TPM) first.

# Step 1: You must manually edit hosts/nixos/default.nix and set:
#   myOS.security.secureBoot.enable = true;
# Then run: sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Step 2: Create and enroll Secure Boot keys
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft

# Step 3: Enable Secure Boot in firmware, then reboot and verify with:
#   bootctl status
#   sbctl status

# Step 4 (Optional): TPM enrollment - See POST-STABILITY.md Section 5
# You must also set myOS.security.tpm.enable = true in default.nix first.
# Example TPM enrollment (verify device path):
# sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/NIXCRYPT --tpm2-pcrs=0+7

echo "Secure Boot keys created/enrolled."
echo "Next steps:"
echo "1. Enable Secure Boot in firmware setup"
echo "2. Reboot and verify: bootctl status, sbctl status"
echo "3. For TPM: enable in default.nix, rebuild, then run systemd-cryptenroll"
