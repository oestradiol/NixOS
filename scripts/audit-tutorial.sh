#!/usr/bin/env bash
set -euo pipefail

echo "== 1. Static repo checks =="
if command -v nix >/dev/null 2>&1; then
  echo "-- nix flake show"
  nix flake show
  echo "-- nix flake check"
  nix flake check
else
  echo "Nix not found; skip static checks."
fi

echo "== 2. Canonical surface review =="
for f in README.md PROJECT-STATE.md REFERENCES.md docs/maps/AUDIT-STATUS.md docs/pipeline/INSTALL-GUIDE.md docs/pipeline/TEST-PLAN.md docs/pipeline/POST-STABILITY.md docs/pipeline/RECOVERY.md docs/maps/SECURITY-SURFACES.md; do
  test -f "$f" && echo "present: $f" || echo "missing: $f"
done

echo "== 3. Persistence / identity surfaces =="
grep -R 'environment.persistence\|fileSystems\."/persist"\|/home/player\|/home/ghost\|machine-id' -n hosts modules docs || true

echo "== 4. Secure Boot / TPM surfaces =="
grep -R "lanzaboote\|secureBoot\|tpm\|cryptenroll\|systemd-boot" -n hosts modules docs scripts || true

echo "== 5. WireGuard / browser / audit / AppArmor / scanner / VM tooling surfaces =="
grep -R "wireguard\|safe-firefox\|safe-tor-browser\|safe-mullvad-browser\|vm-tooling\|bubblewrap\|xdg-dbus-proxy\|security.audit\|auditd\|apparmor\|clamav\|aide\|fwupd\|flatpak" -n hosts modules docs scripts || true

echo "== 6. Runtime checks to run after install =="
cat <<'RUNTIME'
- systemctl --failed
- journalctl -b -p warning
- findmnt -R /
- sudo nft list ruleset
- resolvectl status
- bootctl status
- sbctl status
- systemd-cryptenroll --dump /dev/disk/by-partlabel/NIXCRYPT
- run the exact daily/paranoid steps in docs/pipeline/TEST-PLAN.md
RUNTIME
