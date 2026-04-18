# Kernel hardening — the single module that owns every option, boot
# parameter, sysctl, and module-blacklist entry related to kernel-level
# hardening in the repo. Options and config live together for auditability.
#
# Was previously split across:
#   - modules/core/options.nix       (option declarations)
#   - modules/core/boot.nix          (boot.kernelParams slabNomerge/initOn* etc.)
#   - modules/security/base.nix      (kexec_load_disabled, sysrq, io_uring,
#                                     modules_disabled sysctls, module blacklist)
#
# Stage 2 of the publication refactor consolidates those concerns here.
{ config, lib, ... }:
let
  sec = config.myOS.security;
  kh = sec.kernelHardening;
in {
  options.myOS.security = {
    disableSMT = lib.mkEnableOption "Disable SMT (nosmt=force)";

    usbRestrict = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "USB authorized_default=2 (may block external hubs until explicitly overridden).";
    };

    kernelHardening = {
      initOnAlloc = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Zero pages on allocation (init_on_alloc=1).";
      };
      initOnFree = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Zero pages on free (init_on_free=1).";
      };
      slabNomerge = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Prevent slab cache merging (slab_nomerge).";
      };
      pageAllocShuffle = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Randomize free page list (page_alloc.shuffle=1).";
      };
      moduleBlacklist = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Blacklist dangerous kernel modules (dccp, sctp, rds, tipc, firewire).";
      };
      pti = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Kernel Page Table Isolation (pti=on).";
      };
      vsyscallNone = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Disable vsyscalls (vsyscall=none).";
      };
      oopsPanic = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Panic on kernel oops (kept false for workstation stability until validated on target hardware).";
      };
      moduleSigEnforce = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Only load signed kernel modules (staged off until validated on target hardware).";
      };
      disableIcmpEcho = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Ignore ICMP echo requests (ping).";
      };
      kexecLoadDisabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Disable kexec (kernel.kexec_load_disabled=1).";
      };
      sysrqRestrict = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Restrict SysRq key to keyboard-control functions only (kernel.sysrq=4).";
      };
      modulesDisabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable module loading after boot. Staged off until all required modules are proven loaded at boot.";
      };
      ioUring = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Define io_uring system-wide.";
      };
    };
  };

  config = {
    # ── Boot parameters (was in modules/core/boot.nix) ─────────────────
    boot.kernelParams =
         lib.optionals kh.slabNomerge       [ "slab_nomerge" ]
      ++ lib.optionals kh.initOnAlloc       [ "init_on_alloc=1" ]
      ++ lib.optionals kh.initOnFree        [ "init_on_free=1" ]
      ++ lib.optionals kh.pageAllocShuffle  [ "page_alloc.shuffle=1" ]
      ++ lib.optionals sec.disableSMT       [ "nosmt=force" ]
      ++ lib.optionals sec.usbRestrict      [ "usbcore.authorized_default=2" ]
      ++ lib.optionals kh.pti               [ "pti=on" ]
      ++ lib.optionals kh.vsyscallNone      [ "vsyscall=none" ]
      ++ lib.optionals kh.oopsPanic         [ "oops=panic" ]
      ++ lib.optionals kh.moduleSigEnforce  [ "module.sig_enforce=1" ];

    # ── Sysctls (was in modules/security/base.nix) ─────────────────────
    boot.kernel.sysctl = {
      # Stronger kernel controls (Madaidan-aligned)
      "kernel.kexec_load_disabled" = lib.mkIf kh.kexecLoadDisabled 1;
      "kernel.sysrq"               = lib.mkIf kh.sysrqRestrict 4;  # 4 = keyboard-control functions only
      "kernel.modules_disabled"    = lib.mkIf kh.modulesDisabled 1;
      "kernel.io_uring_disabled"   = kh.ioUring;
      # Madaidan-recommended: ignore ICMP echo (ping) requests (was in boot.nix)
      "net.ipv4.icmp_echo_ignore_all" = lib.mkIf kh.disableIcmpEcho true;
    };

    # ── Module blacklist (was in modules/security/base.nix) ────────────
    boot.blacklistedKernelModules = lib.mkIf kh.moduleBlacklist [
      "dccp" "sctp" "rds" "tipc"
      "firewire-core" "firewire_core" "firewire-ohci"
    ];
  };
}
