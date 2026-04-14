{ config, lib, pkgs, ... }:
let
  sec = config.myOS.security;
in {
  imports = [
    ./governance.nix
    ./networking.nix
    ./wireguard.nix
    ./browser.nix
    ./impermanence.nix
    ./secrets.nix
    ./secure-boot.nix
    ./flatpak.nix
    ./scanners.nix
    ./vm-tooling.nix
    ./sandboxed-apps.nix
    ./privacy.nix
    ./user-profile-binding.nix
  ];

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

  # Hardened sysctl baseline
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = sec.ptraceScope;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.perf_event_paranoid" = 3;

    # Stronger kernel controls (Madaidan-aligned)
    "kernel.kexec_load_disabled" = lib.mkIf sec.kernelHardening.kexecLoadDisabled 1;
    "kernel.sysrq" = lib.mkIf sec.kernelHardening.sysrqRestrict 4;  # 4 = only sync/reboot
    "kernel.modules_disabled" = lib.mkIf sec.kernelHardening.modulesDisabled 1;
    "kernel.io_uring_disabled" = sec.kernelHardening.ioUring;
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
  ] ++ lib.optionals sec.apparmor [
    apparmor-utils
  ];

  # Hardened memory allocator (off by default, staged)
  environment.memoryAllocator.provider =
    lib.mkIf sec.hardenedMemory.enable "graphene-hardened-light";

  # Warn about audit rules + AppArmor compatibility issue
  warnings = lib.mkIf (sec.apparmor && sec.auditd && !sec.auditRules.enable) [
    "AppArmor + custom NixOS audit rules are staged off by default due to a current nixpkgs issue. See docs/POST-STABILITY.md for details and re-enable conditions."
  ];
}
