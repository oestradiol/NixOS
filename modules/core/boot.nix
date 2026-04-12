{ config, lib, pkgs, ... }:
let
  kh = config.myOS.security.kernelHardening;
  sec = config.myOS.security;
  gaming = config.myOS.gaming;
in {
  boot.loader = {
    systemd-boot.enable = lib.mkDefault (!sec.secureBoot.enable);
    efi.canTouchEfiVariables = true;
    timeout = 2;
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

  # ntsync is a gaming-related kernel module (Wine/Proton synchronization)
  # Only loaded on daily profile, not paranoid
  boot.kernelModules = lib.optionals gaming.sysctls [ "ntsync" ];
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "randomize_kstack_offset=on"
    "debugfs=off"
  ] ++ lib.optionals kh.slabNomerge       [ "slab_nomerge" ]
    ++ lib.optionals kh.initOnAlloc        [ "init_on_alloc=1" ]
    ++ lib.optionals kh.initOnFree         [ "init_on_free=1" ]
    ++ lib.optionals kh.pageAllocShuffle   [ "page_alloc.shuffle=1" ]
    ++ lib.optionals sec.disableSMT        [ "nosmt=force" ]
    ++ lib.optionals sec.usbRestrict       [ "usbcore.authorized_default=2" ]
    # Madaidan-recommended kernel hardening
    ++ lib.optionals kh.pti                [ "pti=on" ]
    ++ lib.optionals kh.vsyscallNone       [ "vsyscall=none" ]
    ++ lib.optionals kh.oopsPanic          [ "oops=panic" ]
    ++ lib.optionals kh.moduleSigEnforce   [ "module.sig_enforce=1" ];

  boot.kernel.sysctl = {
    "vm.swappiness" = sec.swappiness;
    "vm.max_map_count" = 2147483642;

    # Zram-optimized settings per Arch Wiki/Pop!_OS
    # page-cluster=0: Read single pages from swap (better for zram compression)
    "vm.page-cluster" = 0;
    # watermark_scale_factor=125: More aggressive page reclaim to zram
    "vm.watermark_scale_factor" = 125;
    # watermark_boost_factor=0: Disable boost (not needed with zram)
    "vm.watermark_boost_factor" = 0;

    "net.ipv4.tcp_mtu_probing" = true;
    "net.ipv4.tcp_fin_timeout" = 5;
    # Madaidan-recommended: ignore ICMP echo (ping) requests
    "net.ipv4.icmp_echo_ignore_all" = lib.mkIf kh.disableIcmpEcho true;
  } // lib.optionalAttrs gaming.sysctls {
    "kernel.sched_cfs_bandwidth_slice_u" = 3000;
    "kernel.sched_latency_ns" = 3000000;
    "kernel.sched_min_granularity_ns" = 300000;
    "kernel.sched_wakeup_granularity_ns" = 500000;
    "kernel.sched_migration_cost_ns" = 50000;
    "kernel.sched_nr_migrate" = 128;
    "kernel.split_lock_mitigate" = 0;
    "kernel.sched_rt_runtime_us" = -1;
  };
}
