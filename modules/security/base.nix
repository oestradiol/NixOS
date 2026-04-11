{ config, lib, pkgs, ... }:
let
  sec = config.myOS.security;
in {
  boot.tmp.cleanOnBoot = true;
  security.protectKernelImage = true;

  security.apparmor.enable = sec.apparmor;
  security.auditd.enable = lib.mkDefault sec.auditd;

  # Core dumps: disable storage and restrict
  systemd.coredump.extraConfig = ''
    Storage=none
    ProcessSizeMax=0
  '';

  # Root account: locked, su restricted to wheel
  users.users.root.hashedPassword = lib.mkIf sec.lockRoot "!";
  security.pam.services.su.requireWheel = sec.lockRoot;

  # Hardened sysctl baseline
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = sec.ptraceScope;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.perf_event_paranoid" = 3;
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    # IPv6 privacy extensions
    "net.ipv6.conf.all.use_tempaddr" = 2;
    "net.ipv6.conf.default.use_tempaddr" = 2;
  };

  # Blacklist rarely-used and dangerous kernel modules
  boot.blacklistedKernelModules = lib.mkIf sec.kernelHardening.moduleBlacklist [
    "dccp" "sctp" "rds" "tipc"
    "firewire-core" "firewire_core" "firewire-ohci"
  ];

  environment.systemPackages = with pkgs; [
    lynis
    aide
    clamav
    lsof
    strace
  ];

  # Hardened memory allocator (off by default, staged)
  environment.memoryAllocator.provider =
    lib.mkIf sec.hardenedMemory.enable "graphene-hardened-light";
}
