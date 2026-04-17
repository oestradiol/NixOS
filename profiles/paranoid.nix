{ config, lib, pkgs, ... }:
{
  # HARDENED WORKSTATION BASELINE
  # This is the default system profile. It is not "maximal isolation at any cost";
  # it is a hardened desktop baseline with explicit, documented residual exposure.
  myOS.profile = "paranoid";
  myOS.gpu = "nvidia";
  myOS.desktopEnvironment = "plasma";

  home-manager.users.ghost = import ../modules/home/ghost.nix;

  myOS.gaming = {
    controllers.enable = false;
  };

  myOS.security = {
    impermanence.enable = true;
    agenix.enable = true;
    persistMachineId = true;
    machineIdValue = null;
    allowSleep = false;

    # Staged until validated with real secrets/endpoints on target hardware.
    wireguardMullvad.enable = false;

    # Sandboxed browser baseline with explicit desktop compromises.
    sandbox.browsers = true;
    sandbox.apps = false;
    sandbox.vms = true;
    sandbox.dbusFilter = true;
    sandbox.x11 = false;
    sandbox.wayland = true;
    sandbox.pipewire = true;
    sandbox.gpu = true;
    sandbox.portals = true;

    disableSMT = true;
    usbRestrict = true;
    swappiness = 180;
    apparmor = true;
    auditd = true;
    lockRoot = true;
    ptraceScope = 2;

    kernelHardening = {
      initOnAlloc = true;
      initOnFree = true;
      slabNomerge = true;
      pageAllocShuffle = true;
      moduleBlacklist = true;
      pti = true;
      vsyscallNone = true;
      oopsPanic = false;
      moduleSigEnforce = false;
      disableIcmpEcho = true;
      kexecLoadDisabled = true;
      sysrqRestrict = true;
      modulesDisabled = false;
      ioUring = 2;
    };

    hardenedMemory.enable = false;
    # Shared bootloader/initrd stage controls remain staged until first successful
    # encrypted boot and recovery validation.
    secureBoot.enable = false;
    tpm.enable = false;
  };
}
