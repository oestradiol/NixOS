{ config, lib, ... }:
{
  # ── Secure Boot (Lanzaboote) ──────────────────────────────────
  config = lib.mkMerge [
    (lib.mkIf config.myOS.security.secureBoot.enable {
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        # NOTE: sbctl create-keys places keys in /var/lib/sbctl by default.
        # This MUST match the path used in scripts/post-install-secureboot-tpm.sh
        pkiBundle = "/var/lib/sbctl";
      };
    })

    # ── TPM-bound LUKS (was tpm.nix) ─────────────────────────────
    (lib.mkIf config.myOS.security.tpm.enable {
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.tpm2.enable = true;
    })
  ];
  # Assertions for GRUB exclusion, EFI access, and TPM→initrd
  # dependency live in modules/security/governance.nix.
}
