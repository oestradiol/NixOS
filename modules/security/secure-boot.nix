{ config, lib, ... }:
{
  # ── Secure Boot (Lanzaboote) ──────────────────────────────────
  config = lib.mkMerge [
    (lib.mkIf config.myOS.security.secureBoot.enable {
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/secureboot";
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
