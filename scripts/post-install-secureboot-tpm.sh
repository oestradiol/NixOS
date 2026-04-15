#!/usr/bin/env bash
set -euo pipefail

# Run only after the first successful normal encrypted boot.
# Review docs/POST-INSTALL.md first.

sudo sbctl create-keys
sudo nixos-rebuild switch --flake /etc/nixos#nixos --specialisation paranoid
sudo sbctl enroll-keys --microsoft

# Example TPM enrollment. Verify the correct device path first.
# sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/NIXCRYPT

echo "Secure Boot keys created/enrolled. TPM enrollment line is intentionally commented until verified."
