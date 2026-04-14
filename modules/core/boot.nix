{ config, lib, pkgs, ... }:
let
  sec = config.myOS.security;
  kh = sec.kernelHardening;
in {
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = true;
    timeout = 2;
  };

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

  boot.kernelParams = [
      "randomize_kstack_offset=on"
      "debugfs=off"
      "slub_debug=FZP"
      "page_poison=1"
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
    ++ lib.optionals kh.moduleSigEnforce   [ "module.sig_enforce=1" ]
    # NVIDIA-specific parameters
    ++ lib.optionals (config.myOS.gpu == "nvidia") [ "nvidia_drm.modeset=1" ];

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

    # Faster TCP port reuse for apps killed and restarted quickly
    "net.ipv4.tcp_fin_timeout" = 5;
    # Madaidan-recommended: ignore ICMP echo (ping) requests
    "net.ipv4.icmp_echo_ignore_all" = lib.mkIf kh.disableIcmpEcho true;
  };
}
