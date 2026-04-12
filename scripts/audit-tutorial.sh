#!/usr/bin/env bash
set -euo pipefail

echo "== 1. Static repo checks =="
if command -v nix >/dev/null 2>&1; then
  echo "-- nix flake show"
  nix flake show
  echo "-- nix flake check (evaluates NixOS configs)"
  nix flake check
else
  echo "Nix not found; skip static checks."
fi

echo "== 2. Import/canonical surface review =="
echo "Checking canonical documentation surfaces..."
for f in PROJECT-STATE.md docs/PRE-INSTALL.md docs/INSTALL-GUIDE.md docs/TEST-PLAN.md docs/POST-STABILITY.md docs/RECOVERY.md docs/PERFORMANCE-NOTES.md docs/audit/SOURCE-TOPIC-LEDGER.md docs/audit/SOURCE-COVERAGE-MATRIX.md; do
  test -f "$f" && echo "present: $f" || echo "missing: $f"
done

echo "== 3. Persistence sanity =="
grep -R "environment.persistence\|fileSystems\.\"/persist\"\|/home/player\|/home/ghost" -n hosts modules || true

echo "== 4. Secure boot / TPM surfaces =="
grep -R "lanzaboote\|secureBoot\|tpm\|cryptenroll\|systemd-boot" -n hosts modules docs || true

echo "== 5. Networking / browser surfaces =="
grep -R "mullvad\|nftables\|safe-firefox\|bubblewrap\|WebRTC\|DNS" -n modules docs || true

echo "== 6. Runtime checks to run after install =="
cat <<'RUNTIME'
- bootctl status
- sbctl status
- systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT
- findmnt -R /
- sudo nft list ruleset
- resolvectl status
- mullvad status
- systemctl --failed
- journalctl -b -p warning
- test WebRTC/DNS through the procedures in docs/TEST-PLAN.md Section 15 (DNS/DoH)
RUNTIME
