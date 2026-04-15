#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if ! command -v sbctl >/dev/null 2>&1; then
  echo "sbctl not found." >&2
  exit 1
fi

echo "This script assumes:"
echo "- myOS.security.secureBoot.enable = true is already committed"
echo "- the system already rebuilt and booted successfully once in that state"
echo "- you are intentionally advancing the POST-STABILITY Secure Boot stage"
read -r -p "Type ENROLL to continue: " CONFIRM
[[ "$CONFIRM" == "ENROLL" ]] || { echo "Aborted."; exit 1; }

sbctl create-keys
sbctl enroll-keys --microsoft

echo "Secure Boot keys created/enrolled."
echo "Next steps:"
echo "1. Enable Secure Boot in firmware setup"
echo "2. Reboot and verify: bootctl status, sbctl status"
echo "3. For TPM: enable myOS.security.tpm.enable, rebuild, then run systemd-cryptenroll manually"
echo "4. Follow docs/pipeline/TEST-PLAN.md and docs/pipeline/RECOVERY.md for post-enrollment validation/recovery"
