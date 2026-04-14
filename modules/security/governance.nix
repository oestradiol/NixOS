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
      message = "Paranoid profile must use sandboxed browsers exclusively (no base Firefox).";
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
      assertion = !isParanoid || config.security.audit.enable != false;
      message = "Paranoid profile must enable the Linux audit subsystem, not just auditd.";
    }
    {
      assertion = !isParanoid || !config.myOS.security.auditRules.enable || config.security.audit.rules != [ ];
      message = "When paranoid profile enables repo audit rules, the resulting audit rule set must be non-empty.";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.vms;
      message = "Paranoid profile must enable VM tooling layer.";
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
      assertion = !isParanoid || (config.myOS.security.kernelHardening.ioUring == 2);
      message = "Paranoid profile must disable io_uring (kernel.io_uring_disabled=2).";
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
      assertion = !isParanoid || config.myOS.security.persistMachineId;
      message = "Paranoid profile must persist machine-id.";
    }
    {
      assertion = !isParanoid || config.myOS.security.machineIdValue == null;
      message = "Paranoid profile must keep a unique host machine-id.";
    }
    {
      assertion = !isParanoid || !config.myOS.security.sandbox.x11;
      message = "Paranoid profile must keep X11 disabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isParanoid || config.myOS.security.sandbox.wayland;
      message = "Paranoid profile must keep Wayland enabled inside bubblewrap sandboxes.";
    }
    {
      assertion = !isDaily || config.myOS.security.sandbox.x11;
      message = "Daily profile must make the X11 compatibility relaxation explicit.";
    }
  ];
}
