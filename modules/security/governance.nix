{ config, lib, ... }:
let
  persistRoot = config.myOS.persistence.root;
  isDaily = config.myOS.profile == "daily";
  isParanoid = config.myOS.profile == "paranoid";
in {
  assertions = [
    {
      assertion = config.users.users ? "player";
      message = "Governance invariant: daily user 'player' must exist.";
    }
    {
      assertion = config.users.users ? "ghost";
      message = "Governance invariant: paranoid user 'ghost' must exist.";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.browsers;
      message = "Paranoid profile must use sandboxed browsers exclusively (no base Firefox). Set myOS.security.sandbox.browsers = true.";
    }
    {
      # Paranoid must use self-owned WireGuard (not Mullvad app)
      # wireguardMullvad.enable = true → self-owned mode (paranoid requirement)
      # wireguardMullvad.enable = false → Mullvad app mode (daily default)
      assertion = !isParanoid || config.myOS.security.wireguardMullvad.enable;
      message = "Paranoid profile must use self-owned WireGuard (myOS.security.wireguardMullvad.enable = true).";
    }
    {
      assertion = !isParanoid || config.myOS.security.impermanence.enable;
      message = "Paranoid profile must keep impermanence enabled.";
    }
    {
      assertion = !isParanoid || config.myOS.security.agenix.enable;
      message = "Paranoid profile must keep secrets management enabled.";
    }
    {
      assertion = !isParanoid || (!config.programs.steam.enable);
      message = "Paranoid profile must not enable Steam.";
    }
    {
      assertion = !config.myOS.security.impermanence.enable || config.fileSystems ? "${persistRoot}";
      message = "Impermanence requires the configured persist root to be mounted.";
    }
    {
      assertion = !(config.myOS.security.secureBoot.enable && config.boot.loader.grub.enable);
      message = "Secure Boot path must not coexist with GRUB.";
    }
    {
      assertion = !config.myOS.security.secureBoot.enable || config.boot.loader.efi.canTouchEfiVariables;
      message = "Secure Boot path requires EFI variable access.";
    }
    {
      assertion = !config.myOS.security.tpm.enable || config.boot.initrd.systemd.enable;
      message = "TPM-bound unlock requires systemd in the initrd.";
    }
    {
      assertion = !isDaily || config.services.displayManager.sddm.enable;
      message = "This design assumes SDDM is enabled for explicit user-choice login.";
    }
    {
      assertion = !isParanoid || !(builtins.elem "wheel" config.users.users."ghost".extraGroups);
      message = "Paranoid user must not be in the wheel group by default.";
    }
    {
      assertion = !isParanoid || config.myOS.security.disableSMT;
      message = "Paranoid profile must enable disableSMT (nosmt=force).";
    }
    {
      assertion = !isParanoid || config.myOS.security.usbRestrict;
      message = "Paranoid profile must enable USB restriction (authorized_default=2).";
    }
    {
      assertion = !isParanoid || config.myOS.security.auditd;
      message = "Paranoid profile must enable audit daemon.";
    }
    {
      # Check both new and legacy option paths
      assertion = !isParanoid || config.myOS.security.sandbox.vms;
      message = "Paranoid profile must enable VM isolation layer. Set myOS.security.sandbox.vms = true.";
    }
    {
      assertion = !isParanoid || !config.myOS.gaming.sysctls;
      message = "Paranoid profile must disable gaming sysctls.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.initOnFree;
      message = "Paranoid profile must enable initOnFree kernel hardening.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.pageAllocShuffle;
      message = "Paranoid profile must enable pageAllocShuffle kernel hardening.";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.kexecLoadDisabled;
      message = "Paranoid profile must disable kexec_load (kernel.kexec_load_disabled=1).";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.sysrqRestrict;
      message = "Paranoid profile must restrict SysRq key (kernel.sysrq).";
    }
    {
      assertion = !isParanoid || config.myOS.security.kernelHardening.ioUringDisabled;
      message = "Paranoid profile must disable io_uring (kernel.io_uring_disabled=1).";
    }
    {
      assertion = !isParanoid || !config.programs.gamescope.enable;
      message = "Paranoid profile must not enable gamescope.";
    }
    {
      assertion = !isParanoid || !config.programs.gamemode.enable;
      message = "Paranoid profile must not enable gamemode.";
    }
    {
      assertion = !isParanoid || !config.services.wivrn.enable;
      message = "Paranoid profile must not enable wivrn.";
    }
    {
      assertion = !isDaily || !config.myOS.security.hardenedMemory.enable;
      message = "Daily profile must not enable hardened memory allocator.";
    }
    {
      assertion = config.myOS.gpu == "nvidia" || config.myOS.gpu == "amd";
      message = "GPU option must be set to either 'nvidia' or 'amd'.";
    }
    {
      # Check both new and legacy option paths
      assertion = !isParanoid || config.myOS.security.sandbox.apps;
      message = "Paranoid profile must enable sandboxed applications. Set myOS.security.sandbox.apps = true.";
    }
    {
      assertion = !isParanoid || (config.myOS.security.persistMachineId && config.myOS.security.machineIdValue == "b08dfa6083e7567a1921a715000001fb");
      message = "Paranoid profile must use Whonix shared machine-id (privacy: blends with Whonix users). Note: This conflicts with systemd's unique-id guidance and may cause compatibility issues. This is a deliberate privacy-over-compatibility tradeoff.";
    }
  ];
}
