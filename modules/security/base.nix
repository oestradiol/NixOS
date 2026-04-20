{ config, lib, pkgs, ... }:
let
  sec = config.myOS.security;
in {
  imports = [
    ./browser.nix
    ./flatpak.nix
    ./governance.nix
    ./impermanence.nix
    ./kernel-hardening.nix
    ./networking.nix
    ./privacy.nix
    ./sandbox.nix
    ./sandboxed-apps.nix
    ./scanners.nix
    ./secrets.nix
    ./secure-boot.nix
    ./user-profile-binding.nix
    ./vm-tooling.nix
    ./wireguard.nix
  ];

  # Option declarations for the security knobs consumed here. Sibling
  # namespaces (sandbox, kernelHardening, wireguardMullvad, secureBoot,
  # tpm, impermanence, persistMachineId, machineIdValue, agenix, aide,
  # pamProfileBinding, vm) are declared in their respective modules.
  options.myOS.security = {
    ptraceScope = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "kernel.yama.ptrace_scope (0=classic, 1=restricted, 2=attached-only, 3=no-attach).";
    };
    swappiness = lib.mkOption {
      type = lib.types.int;
      default = 180;
      description = ''
        vm.swappiness (0-200, default 180 for zram-backed hardened workstation baseline).
      '';
    };
    apparmor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "AppArmor MAC framework.";
    };
    auditd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Audit daemon enabled by default on the hardened baseline.";
    };
    auditRules = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Load custom NixOS audit rules (separate from running auditd). Currently defaulted off due to AppArmor + audit-rules incompatibility on affected nixpkgs revisions (see docs/pipeline/POST-STABILITY.md). Re-enable only after validating on your target nixpkgs revision.";
      };
    };
    lockRoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lock root account and restrict su to wheel group.";
    };
    hardenedMemory.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Graphene hardened allocator (staged off until validated).";
    };
    allowSleep = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow system sleep states: suspend, hibernate, hybrid-sleep.
      '';
    };
  };

  config = {
    boot.tmp.cleanOnBoot = true;
    security.protectKernelImage = true;

    security.apparmor.enable = sec.apparmor;
    services.dbus.apparmor = if sec.apparmor then "required" else "disabled";

    security.auditd.enable = sec.auditd;
    security.audit = lib.mkIf sec.auditd {
      enable = true;
      backlogLimit = 8192;
      failureMode = "printk";
      rateLimit = 0;
      rules = lib.optionals sec.auditRules.enable [
        # Privileged execution and kernel/module changes
        "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid"
        "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k setuid"
        "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k setgid"
        "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k setgid"
        "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k kernel_modules"
        "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k kernel_modules"

        # Mount and identity / privilege configuration changes
        "-a always,exit -F arch=b64 -S mount,umount2 -F auid>=1000 -F auid!=unset -k mounts"
        "-a always,exit -F arch=b32 -S mount,umount2 -F auid>=1000 -F auid!=unset -k mounts"
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/group -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        "-w /etc/gshadow -p wa -k identity"
        "-w /etc/sudoers -p wa -k scope"
        "-w /etc/sudoers.d/ -p wa -k scope"

        # Auth, network, and time changes
        "-w /var/log/lastlog -p wa -k logins"
        "-w /var/run/utmp -p wa -k session"
        "-w /var/log/wtmp -p wa -k session"
        "-w /etc/hosts -p wa -k network_modifications"
        "-w /etc/NetworkManager/system-connections/ -p wa -k network_modifications"
        "-w /etc/wireguard/ -p wa -k network_modifications"
        "-a always,exit -F arch=b64 -S sethostname,setdomainname -k network_modifications"
        "-a always,exit -F arch=b32 -S sethostname,setdomainname -k network_modifications"
        "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
        "-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time_change"

        # File deletion and permission changes by real users
        "-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat,rmdir -F auid>=1000 -F auid!=unset -k delete"
        "-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat,rmdir -F auid>=1000 -F auid!=unset -k delete"
        "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,lchown,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod"
        "-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,lchown,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod"
      ];
    };

    security.auditd.settings = lib.mkIf sec.auditd {
      num_logs = 10;
      max_log_file = 100;
      max_log_file_action = "rotate";
      space_left = "25%";
      space_left_action = "syslog";
      admin_space_left = "10%";
      admin_space_left_action = "single";
      disk_full_action = "single";
      disk_error_action = "single";
    };

    # Core dumps: disable storage and restrict
    systemd.coredump.extraConfig = ''
      Storage=none
      ProcessSizeMax=0
    '';

    # Root account: locked, su restricted to wheel
    users.users.root.hashedPassword = lib.mkIf sec.lockRoot "!";
    security.pam.services.su.requireWheel = sec.lockRoot;

    # Hardened sysctl baseline.
    # The kernel.kexec_load_disabled / kernel.sysrq / kernel.modules_disabled /
    # kernel.io_uring_disabled sysctls and the module blacklist live in
    # modules/security/kernel-hardening.nix with their option declarations.
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
    };

    environment.systemPackages = with pkgs; [
      lynis
      aide
      clamav
      lsof
      strace
    ] ++ lib.optionals sec.apparmor [
      apparmor-utils
    ];

    # Hardened memory allocator (off by default, staged)
    environment.memoryAllocator.provider =
      lib.mkIf sec.hardenedMemory.enable "graphene-hardened-light";

    # Warn about audit rules + AppArmor compatibility issue
    warnings = lib.mkIf (sec.apparmor && sec.auditd && !sec.auditRules.enable) [
      "AppArmor + custom NixOS audit rules are staged off by default due to a current nixpkgs issue. See docs/pipeline/POST-STABILITY.md for details and re-enable conditions."
    ];
  };
}
