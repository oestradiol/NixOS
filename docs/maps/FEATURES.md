## 1. Full code inventory

This is what the repo currently contains.

### Base system

* single NixOS host via flake
* one default profile: `paranoid`
* one specialization: `daily`
* one encrypted LUKS root device
* Btrfs subvolumes
* tmpfs `/`
* persistent `/nix`, `/persist`, `/var/log`
* timezone `America/Sao_Paulo`
* hostname `nixos`
* Home Manager
* Stylix
* impermanence
* lanzaboote module available
* agenix module available

### Users and identity

* `player` = daily user
* `ghost` = hardened user
* mutable users enabled
* root account lock path supported
* `sudo` wheel restriction when root is locked
* persisted identity files via impermanence
* machine-id persistence model present

### Boot and kernel baseline

* systemd-boot enabled by default
* EFI write support enabled
* hardened kernel params including:

  * `randomize_kstack_offset=on`
  * `debugfs=off`
  * `slub_debug=FZP`
  * `page_poison=1`
  * optional `slab_nomerge`
  * optional `init_on_alloc=1`
  * optional `init_on_free=1`
  * optional `page_alloc.shuffle=1`
  * optional `nosmt=force`
  * optional `usbcore.authorized_default=2`
  * optional `pti=on`
  * optional `vsyscall=none`
  * optional `oops=panic`
  * optional `module.sig_enforce=1`
  * NVIDIA modeset param when relevant
* hardened sysctls including:

  * `dmesg_restrict`
  * `kptr_restrict`
  * `ptrace_scope`
  * unprivileged BPF disabled
  * BPF JIT hardening
  * `perf_event_paranoid`
  * `kexec_load_disabled`
  * restricted SysRq
  * `io_uring_disabled`
  * protected symlink/hardlink/fifo/regular
  * `suid_dumpable=0`
  * `rp_filter`
  * redirect disabling
  * syncookies
  * RFC1337
  * IPv6 temp addresses
* dangerous kernel module blacklist:

  * `dccp`
  * `sctp`
  * `rds`
  * `tipc`
  * firewire modules

### Filesystem and mount model

* `/` on tmpfs (capped at 16G; RAM+swap backed, only uses what is held)
* `/tmp` on its own tmpfs (`size=50%`, `nosuid,nodev`) — isolates /tmp spikes from the root fs
* `boot.tmp.cleanOnBoot = true` wipes `/tmp` at every boot
* `/boot` on vfat
* `/nix` on Btrfs `@nix`
* `/persist` on Btrfs `@persist`
* `/var/log` on Btrfs `@log`
* paranoid:

  * `/home/ghost` on tmpfs
  * `/persist/home/ghost` on Btrfs `@home-paranoid`
* daily:

  * `/home/player` on Btrfs `@home-daily`
  * `/swap` on Btrfs `@swap`
  * 8 GiB swapfile
* boot-time mount invariant service:

  * daily must not mount ghost home surfaces
  * paranoid must not mount player home surface

### Desktop and session

* Plasma 6
* greetd + regreet (Wayland-native greeter)
* X server explicitly disabled
* keyboard layout via XKB_DEFAULT_LAYOUT (Wayland-native)
* default session `plasma` (Wayland)
* Polkit
* D-Bus (default daemon, broker commented out)
* udisks2
* printing disabled
* OpenSSH disabled
* fwupd enabled
* Zsh enabled
* Git + Git LFS enabled
* GnuPG agent with SSH support
* locale:

  * default `en_GB.UTF-8`
  * many `pt_BR.UTF-8` locale categories
* input method:

  * fcitx5
  * mozc-ut
  * fcitx5-gtk

### Audio / performance / health

* PulseAudio disabled
* PipeWire enabled
* ALSA enabled
* 32-bit ALSA enabled
* Pulse compatibility
* JACK enabled
* WirePlumber enabled
* RTKit enabled
* earlyoom enabled
* journald size limits configured
* zram enabled with zstd
* fstrim enabled
* power management tied to security option
* systemd sleep targets masked when sleep disabled

### GPU stack

* NVIDIA module imported
* AMD module imported
* current profile defaults to NVIDIA
* NVIDIA modesetting enabled
* graphics acceleration enabled
* daily gaming also enables 32-bit graphics

### Networking and privacy baseline

* NetworkManager enabled
* daily Wake-on-LAN on `enp5s0` (layer-2 magic packets; no global firewall port)
* daily: UDP 9 allowed ONLY on `enp5s0` for WoL-over-UDP compatibility (LAN-scoped, never global)
* daily: Mullvad app mode (GUI + daemon)
* paranoid: self-owned WireGuard path (staged off by default)
* resolved enabled system-wide
* Mullvad daemon enabled on daily only
* firewall: either nixpkgs firewall OR nftables is active at all times (enforced by governance assertion)
* `services.geoclue2.enable = false` (Plasma 6 auto-enables it; we mkForce it off — MLS identity beacon)
* `services.avahi` suppressed on both profiles by default; daily can opt in via `myOS.vr.lanDiscovery.enable`
* privacy layer:

  * paranoid:

    * MAC randomization for Wi-Fi and Ethernet
    * NetworkManager Wi-Fi randomization
    * TCP timestamps disabled
  * daily:

    * stable per-network MAC
    * scan randomization
    * TCP timestamps enabled

### VR / LAN discovery (daily only)

* `services.wivrn.enable = true` on daily
* `services.wivrn.openFirewall` forced to `false` (upstream opens TCP/UDP 9757 on every interface)
* WiVRn port 9757 opened ONLY on interfaces listed in `myOS.vr.lanInterfaces` (default `[ "enp5s0" ]`)
* `myOS.vr.lanDiscovery.enable`: opt-in knob (default OFF)

  * OFF: `services.avahi` disabled; connect by typing the host IP manually in the headset app
  * ON : `services.avahi.enable = true`, advertising scoped to `myOS.vr.lanInterfaces` (never broadcasts on VPN / bluetooth / guest interfaces)
* paranoid never imports VR, so avahi stays off unconditionally

### Browser/security sandboxing

* shared bubblewrap constructor in `sandbox-core.nix`
* wrapped sandbox can control:

  * network
  * GPU
  * D-Bus proxy
  * Wayland
  * X11
  * PipeWire
  * portals
  * writable persisted app paths
  * minimal or full `/etc`
* wrapper now clears inherited environment
* browser wrappers use minimal `/etc`
* filtered D-Bus path via `xdg-dbus-proxy`

### Browser model

* daily:

  * plain `programs.firefox`
  * managed by enterprise policies
* paranoid:

  * `safe-firefox`
  * vendored arkenfox base + repo overrides
  * dedicated persisted profile `.mozilla/safe-firefox`
* also wrapped:

  * `safe-tor-browser`
  * `safe-mullvad-browser`

### Flatpak

* Flatpak enabled
* Flathub auto-added
* xdg-desktop-portal enabled
* GTK portal enabled
* intended app role:

  * Signal
  * Spotify
  * Bitwarden
  * Vesktop
  * Obsidian
* Flatpak treated as containment for relatively trusted GUI apps, not hostile workloads

### Daily app wrappers

* `safe-vrcx`
* `safe-windsurf`
* desktop launchers for both
* file chooser / portal talk allowances
* persisted config/data/cache per app

### VM tooling

* enabled only when sandbox VMs are enabled
* libvirtd enabled
* `qemu_kvm`
* swtpm enabled
* virt-manager enabled
* repo VM helper script `repo-vm-class`
* repo networks:

  * NAT network
  * isolated network
* four classes:

  * `trusted-work-vm`
  * `risky-browser-vm`
  * `malware-research-vm`
  * `throwaway-untrusted-file-vm`
* transient overlay cleanup logic present

### Monitoring / integrity / security services

* AppArmor enablement path
* D-Bus AppArmor mediation when AppArmor enabled
* audit subsystem on paranoid
* `auditd` on paranoid
* custom audit rules exist but staged off unless option enabled
* ClamAV installed
* ClamAV updater enabled
* daily ClamAV timer/service
* weekly deep ClamAV timer/service
* profile-specific ClamAV home targeting
* AIDE installed
* AIDE config is high-signal only
* optional AIDE service/timer behind `myOS.security.aide.enable`
* coredumps disabled
* `lynis`, `lsof`, `strace` installed
* AppArmor tools installed when AppArmor enabled

### Secrets / secure boot / governance

* agenix support
* secure boot module present
* TPM module path present
* governance module present
* profile-user binding enforced via account locking
* PAM profile-binding module present but superseded

## 2. Profile split

### Paranoid

* default boot profile
* `ghost` user model
* tmpfs home + allowlisted persistence
* sandboxed browsers on
* sandboxed apps off
* VM tooling on
* X11 off
* Wayland on
* PipeWire on
* GPU on
* portals on
* D-Bus filtering on
* SMT disabled
* USB restricted
* AppArmor on
* auditd on
* ptrace scope = 2
* stricter memory/kernel settings than daily
* controllers off
* no Steam/gaming stack imported
* self-owned WireGuard path (staged off by default)

### Daily

* specialization
* `player` user model
* persistent home
* browser wrappers off
* app wrappers on
* VM tooling off
* X11 on
* Wayland on
* PipeWire on
* GPU on
* portals on
* D-Bus filtering on
* AppArmor on
* auditd off
* ptrace scope = 1
* SMT not disabled
* USB restriction off
* controllers on
* gaming module imported
* Mullvad app mode intended as easier mobility path

### Daily-only gaming/social stack

* Steam
* steam hardware
* gamescope
* gamescope Steam session
* gamemode
* NT sync kernel module
* gaming scheduler sysctls
* VR module import
* controllers module import
* Flatpak social/desktop app path
* Mullvad client package in Home Manager