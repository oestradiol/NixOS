{ config, lib, pkgs, ... }:
{
  # DAILY SPECIALISATION
  # Purpose: make every security weakening explicit by overriding the hardened base.
  myOS.profile = lib.mkForce "daily";
  myOS.gpu = lib.mkForce "nvidia";
  myOS.desktopEnvironment = lib.mkForce "plasma";

  # home-manager binding for daily-profile users is owned by the template's
  # accounts/*.nix files via myOS.users.<name>.homeManagerConfig.

  myOS.gaming = {
    enable = lib.mkForce true;          # master gate for the gaming stack
    controllers.enable = lib.mkForce true;
    # steam / gamescope / gamemode / vr default to gaming.enable so they
    # follow the master gate automatically.
  };

  myOS.storage.swap.enable = lib.mkForce true;

  # Daily networking features
  myOS.networking.wakeOnLan.enable = lib.mkForce true;
  myOS.networking.mullvadAppMode.enable = lib.mkForce true;

  # Relaxed privacy posture for compatibility
  myOS.privacy.posture = lib.mkForce "relaxed";

  myOS.security = {
    impermanence.enable = lib.mkForce true;
    agenix.enable = lib.mkForce true;
    persistMachineId = lib.mkForce true;
    machineIdValue = lib.mkForce null;
    allowSleep = lib.mkForce false;

    # Daily networking relaxes to Mullvad app mode for easier mobility.
    wireguardMullvad.enable = lib.mkForce false;

    # Daily relaxations: more compatible desktop path, weaker containment.
    sandbox.browsers = lib.mkForce false;
    sandbox.apps = lib.mkForce true;
    sandbox.vms = lib.mkForce false;
    sandbox.dbusFilter = lib.mkForce true;
    sandbox.x11 = lib.mkForce true;
    sandbox.wayland = lib.mkForce true;
    sandbox.pipewire = lib.mkForce true;
    sandbox.gpu = lib.mkForce true;
    sandbox.portals = lib.mkForce true;

    disableSMT = lib.mkForce false;
    usbRestrict = lib.mkForce false;
    swappiness = lib.mkForce 150;
    apparmor = lib.mkForce true;
    auditd = lib.mkForce false;
    lockRoot = lib.mkForce true;
    ptraceScope = lib.mkForce 1;

    kernelHardening = {
      initOnAlloc = lib.mkForce true;
      initOnFree = lib.mkForce false;
      slabNomerge = lib.mkForce true;
      pageAllocShuffle = lib.mkForce true;
      moduleBlacklist = lib.mkForce true;
      pti = lib.mkForce true;
      vsyscallNone = lib.mkForce true;
      oopsPanic = lib.mkForce false;
      moduleSigEnforce = lib.mkForce false;
      disableIcmpEcho = lib.mkForce false;
      kexecLoadDisabled = lib.mkForce true;
      sysrqRestrict = lib.mkForce true;
      modulesDisabled = lib.mkForce false;
      ioUring = lib.mkForce 1;
    };

    hardenedMemory.enable = lib.mkForce false;
    # Shared bootloader/initrd stage controls remain staged until first successful
    # encrypted boot and recovery validation.
    secureBoot.enable = lib.mkForce false;
    tpm.enable = lib.mkForce false;
  };

  # modules/desktop/gaming.nix is now imported unconditionally from
  # modules/desktop/base.nix and self-gated on myOS.gaming.enable.
}
