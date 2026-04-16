# VM tooling layer
# Exposes libvirt/QEMU/KVM tooling and repo-managed helper automation.
# This is stronger than local bubblewrap containment when a workload is actually run in a VM,
# but enabling this module does not by itself make every guest hardened. The repo encodes
# four workflow classes and host-side defaults; guest images still need to be prepared and validated.
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkDefault optionalString escapeShellArg concatStringsSep;
  profile = config.myOS.profile;
  vmsEnabled = config.myOS.security.sandbox.vms;
  vmCfg = config.myOS.security.vm;
  kvmModule =
    if config.hardware.cpu.amd.updateMicrocode or false then "kvm-amd"
    else if config.hardware.cpu.intel.updateMicrocode or false then "kvm-intel"
    else null;
  repoNat = vmCfg.natNetworkName;
  repoIsolated = vmCfg.isolatedNetworkName;
  storageRoot = vmCfg.storageRoot;
  baseDir = vmCfg.defaultBaseImageDir;

  repoNatXml = pkgs.writeText "${repoNat}.xml" ''
    <network>
      <name>${repoNat}</name>
      <forward mode='nat'/>
      <bridge name='virbr-repo-nat' stp='on' delay='0'/>
      <ip address='192.168.151.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.151.100' end='192.168.151.254'/>
        </dhcp>
      </ip>
    </network>
  '';

  repoIsolatedXml = pkgs.writeText "${repoIsolated}.xml" ''
    <network>
      <name>${repoIsolated}</name>
      <bridge name='virbr-repo-iso' stp='on' delay='0'/>
      <ip address='192.168.152.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.152.100' end='192.168.152.254'/>
        </dhcp>
      </ip>
    </network>
  '';

  vmClassHelper = pkgs.writeShellApplication {
    name = "repo-vm-class";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      gawk
      gnugrep
      gnused
      libvirt
      qemu_kvm
      virt-viewer
      virt-manager
      OVMF
    ];
    text = ''
      set -euo pipefail

      STORAGE_ROOT=${escapeShellArg storageRoot}
      BASE_DIR=${escapeShellArg baseDir}
      NAT_NETWORK=${escapeShellArg repoNat}
      ISOLATED_NETWORK=${escapeShellArg repoIsolated}

      usage() {
        cat <<USAGE
      repo-vm-class <command> [args]

      Commands:
        policy <class>
        create <class> <name> [base-image]
               [--memory MB] [--vcpus N] [--disk-gb N]
               [--osinfo ID] [--network nat|isolated|none]
               [--allow-clipboard] [--share-ro /host/path]
               [--persistent]
        reset <class> <name> [base-image]
               [same optional flags as create]
        view <name>
        destroy <name>

      Classes:
        trusted-work-vm
        risky-browser-vm
        malware-research-vm
        throwaway-untrusted-file-vm
      USAGE
      }

      require_args() {
        if [ "$#" -lt "$1" ]; then
          usage >&2
          exit 1
        fi
      }

      class_defaults() {
        case "$1" in
          trusted-work-vm)
            CLASS_MEMORY=6144
            CLASS_VCPUS=4
            CLASS_DISK_GB=80
            CLASS_NETWORK="nat"
            CLASS_AUDIO="yes"
            CLASS_TRANSIENT="no"
            CLASS_DEFAULT_CLIPBOARD="no"
            CLASS_ALLOW_SHARE="optional"
            ;;
          risky-browser-vm)
            CLASS_MEMORY=4096
            CLASS_VCPUS=4
            CLASS_DISK_GB=40
            CLASS_NETWORK="nat"
            CLASS_AUDIO="no"
            CLASS_TRANSIENT="yes"
            CLASS_DEFAULT_CLIPBOARD="no"
            CLASS_ALLOW_SHARE="no"
            ;;
          malware-research-vm)
            CLASS_MEMORY=4096
            CLASS_VCPUS=2
            CLASS_DISK_GB=60
            CLASS_NETWORK="none"
            CLASS_AUDIO="no"
            CLASS_TRANSIENT="yes"
            CLASS_DEFAULT_CLIPBOARD="no"
            CLASS_ALLOW_SHARE="no"
            ;;
          throwaway-untrusted-file-vm)
            CLASS_MEMORY=4096
            CLASS_VCPUS=2
            CLASS_DISK_GB=30
            CLASS_NETWORK="none"
            CLASS_AUDIO="no"
            CLASS_TRANSIENT="yes"
            CLASS_DEFAULT_CLIPBOARD="no"
            CLASS_ALLOW_SHARE="ro-only"
            ;;
          *)
            echo "Unknown class: $1" >&2
            exit 1
            ;;
        esac
      }

      print_policy() {
        class_defaults "$1"
        case "$1" in
          trusted-work-vm)
            cat <<POLICY
      Class: trusted-work-vm
      1. Threat class: lower-risk work separated from the host.
      2. Boundary: clipboard off by default and opt-in only; no shared folders by default; optional read-only share if explicitly requested; USB passthrough off; guest agent off; minimal display integration.
      3. Network: ${repoNat} NAT by default.
      4. Disposability: persistent by default; snapshot before major changes.
      5. Guest baseline: operator-managed updates, guest firewall, separate credentials.
      6. Workflow: ordinary compartmentalized work.
      POLICY
            ;;
          risky-browser-vm)
            cat <<POLICY
      Class: risky-browser-vm
      1. Threat class: suspicious or high-tracking browsing beyond host-wrapper trust.
      2. Boundary: clipboard off; no shared folders; no USB passthrough; guest agent off; minimal display integration.
      3. Network: ${repoNat} NAT by default.
      4. Disposability: transient overlay by default.
      5. Guest baseline: browser-focused guest, no host account reuse.
      6. Workflow: risky browsing sessions, then reset.
      POLICY
            ;;
          malware-research-vm)
            cat <<POLICY
      Class: malware-research-vm
      1. Threat class: hostile binaries or clearly malicious content.
      2. Boundary: clipboard off; no shared folders; no USB passthrough; guest agent off; minimal display; audio off.
      3. Network: none by default; optional isolated-only network.
      4. Disposability: transient overlay by default.
      5. Guest baseline: minimal image, separate identity, no productivity accounts.
      6. Workflow: do not weaken host policy; use isolated analysis path.
      POLICY
            ;;
          throwaway-untrusted-file-vm)
            cat <<POLICY
      Class: throwaway-untrusted-file-vm
      1. Threat class: unknown documents, archives, and media.
      2. Boundary: clipboard off; no shared folders by default; optional explicit read-only import share; no USB passthrough; guest agent off; minimal display.
      3. Network: none by default; optional temporary ${repoNat} NAT only when needed.
      4. Disposability: transient overlay by default.
      5. Guest baseline: small guest image, no account reuse.
      6. Workflow: open unknown files here first, escalate to malware-research-vm if behavior looks hostile.
      POLICY
            ;;
        esac
      }

      command=''${1:-}
      case "$command" in
        policy)
          require_args 2 "$@"
          print_policy "$2"
          exit 0
          ;;
        create|reset)
          require_args 3 "$@"
          ACTION="$command"
          CLASS="$2"
          NAME="$3"
          shift 3
          class_defaults "$CLASS"

          MEMORY="$CLASS_MEMORY"
          VCPUS="$CLASS_VCPUS"
          DISK_GB="$CLASS_DISK_GB"
          NETWORK_MODE="$CLASS_NETWORK"
          AUDIO="$CLASS_AUDIO"
          TRANSIENT="$CLASS_TRANSIENT"
          ALLOW_CLIPBOARD="$CLASS_DEFAULT_CLIPBOARD"
          SHARE_RO=""
          PERSISTENT_OVERRIDE=""
          OSINFO="detect=on,require=off"
          BASE_IMAGE=""

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --memory) MEMORY="$2"; shift 2 ;;
              --vcpus) VCPUS="$2"; shift 2 ;;
              --disk-gb) DISK_GB="$2"; shift 2 ;;
              --osinfo) OSINFO="$2"; shift 2 ;;
              --network) NETWORK_MODE="$2"; shift 2 ;;
              --allow-clipboard) ALLOW_CLIPBOARD="yes"; shift ;;
              --share-ro) SHARE_RO="$2"; shift 2 ;;
              --persistent) PERSISTENT_OVERRIDE="yes"; shift ;;
              --*) echo "Unknown option: $1" >&2; exit 1 ;;
              *)
                if [ -z "$BASE_IMAGE" ]; then BASE_IMAGE="$1"; shift; else echo "Unexpected argument: $1" >&2; exit 1; fi
                ;;
            esac
          done

          [ -n "$BASE_IMAGE" ] || BASE_IMAGE="$BASE_DIR/$CLASS.qcow2"
          if [ ! -f "$BASE_IMAGE" ]; then
            echo "Base image not found: $BASE_IMAGE" >&2
            exit 1
          fi

          if [ "$CLASS_ALLOW_SHARE" = "no" ] && [ -n "$SHARE_RO" ]; then
            echo "$CLASS does not permit host file shares." >&2
            exit 1
          fi
          if [ "$CLASS_ALLOW_SHARE" = "ro-only" ] && [ -n "$SHARE_RO" ] && [ ! -d "$SHARE_RO" ]; then
            echo "Requested read-only share does not exist: $SHARE_RO" >&2
            exit 1
          fi
          if [ "$CLASS" = "malware-research-vm" ] && [ "$NETWORK_MODE" = "nat" ]; then
            echo "malware-research-vm may not use NAT. Use --network isolated or leave the default none." >&2
            exit 1
          fi

          TRANSIENT="$CLASS_TRANSIENT"
          if [ "$PERSISTENT_OVERRIDE" = "yes" ]; then TRANSIENT="no"; fi

          PERSIST_DIR="$STORAGE_ROOT/persistent/$CLASS"
          TRANSIENT_DIR="$STORAGE_ROOT/transient/$CLASS"
          mkdir -p "$PERSIST_DIR" "$TRANSIENT_DIR"

          if [ "$TRANSIENT" = "yes" ]; then
            DISK_PATH="$TRANSIENT_DIR/$NAME.qcow2"
          else
            DISK_PATH="$PERSIST_DIR/$NAME.qcow2"
          fi

          if [ "$ACTION" = "reset" ]; then
            virsh destroy "$NAME" >/dev/null 2>&1 || true
            virsh undefine "$NAME" --nvram >/dev/null 2>&1 || true
            rm -f "$DISK_PATH"
          else
            if virsh dominfo "$NAME" >/dev/null 2>&1; then
              echo "Domain already exists: $NAME" >&2
              exit 1
            fi
          fi

          rm -f "$DISK_PATH"
          qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$DISK_PATH" "''${DISK_GB}G" >/dev/null

          GRAPHICS_ARGS=(--graphics "spice,listen=none")
          SOUND_ARGS=()
          if [ "$AUDIO" = "yes" ]; then
            SOUND_ARGS=(--sound default --audio type=spice)
          fi

          NETWORK_ARGS=()
          case "$NETWORK_MODE" in
            nat) NETWORK_ARGS=(--network "network=$NAT_NETWORK,model=virtio") ;;
            isolated) NETWORK_ARGS=(--network "network=$ISOLATED_NETWORK,model=virtio") ;;
            none) NETWORK_ARGS=(--network none) ;;
            *) echo "Unknown network mode: $NETWORK_MODE" >&2; exit 1 ;;
          esac

          TRANSIENT_ARGS=()
          if [ "$TRANSIENT" = "yes" ]; then
            TRANSIENT_ARGS=(--transient --destroy-on-exit)
          fi

          virt-install \
            --connect qemu:///system \
            --name "$NAME" \
            --import \
            --memory "$MEMORY" \
            --vcpus "$VCPUS" \
            --cpu host-passthrough \
            --machine q35 \
            --controller type=usb,model=none \
            --disk "path=$DISK_PATH,format=qcow2,bus=virtio,discard=unmap" \
            --rng /dev/urandom \
            --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
            --boot uefi \
            --video virtio \
            "''${SOUND_ARGS[@]}" \
            "''${GRAPHICS_ARGS[@]}" \
            --channel none \
            "''${NETWORK_ARGS[@]}" \
            --osinfo "$OSINFO" \
            --noautoconsole \
            "''${TRANSIENT_ARGS[@]}"

          if [ "$ALLOW_CLIPBOARD" = "yes" ]; then
            virt-xml "$NAME" --add-device --channel "qemu-vdagent,target.type=virtio,target.name=com.redhat.spice.0"
            echo "Clipboard opt-in requested: qemu-vdagent channel added; guest-side agent support must still be present before copy/paste works."
          fi

          if [ -n "$SHARE_RO" ]; then
            virt-xml "$NAME" --add-device --filesystem "source=$SHARE_RO,target=repo-import,readonly=on,driver.type=virtiofs,accessmode=passthrough"
          fi

          if [ "$TRANSIENT" = "no" ]; then
            virsh autostart "$NAME" >/dev/null 2>&1 || true
          fi

          cat <<DONE
      Created $CLASS as $NAME
      Base image: $BASE_IMAGE
      Disk path: $DISK_PATH
      Network mode: $NETWORK_MODE
      Clipboard: $ALLOW_CLIPBOARD
      Read-only import share: ''${SHARE_RO:-none}
      Persistent: $([ "$TRANSIENT" = "yes" ] && echo no || echo yes)
      Next steps:
        repo-vm-class policy $CLASS
        repo-vm-class view $NAME
      DONE
          ;;
        view)
          require_args 2 "$@"
          exec virt-viewer --connect qemu:///system --wait "$2"
          ;;
        destroy)
          require_args 2 "$@"
          virsh destroy "$2" >/dev/null 2>&1 || true
          virsh undefine "$2" --nvram >/dev/null 2>&1 || true
          find "$STORAGE_ROOT/transient" -type f -name "$2.qcow2" -delete >/dev/null 2>&1 || true
          ;;
        *)
          usage >&2
          exit 1
          ;;
      esac
    '';
  };
in {
  config = mkIf vmsEnabled {
    warnings = lib.optional (!(config.hardware.cpu.amd.updateMicrocode or false || config.hardware.cpu.intel.updateMicrocode or false))
      "VM tooling could not infer CPU vendor from hardware.cpu.*.updateMicrocode; kernel module autoload is left untouched. Set the hardware target explicitly before enabling VMs if libvirt/QEMU does not load the right KVM module on its own.";
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;
    virtualisation.libvirtd.qemu.swtpm.enable = true;
    virtualisation.libvirtd.qemu.verbatimConfig = ''
      seccomp_sandbox = 1
      spice_tls = 1
      vnc_tls = 1
      vnc_tls_x509_verify = 1
    '';

    programs.virt-manager.enable = true;
    boot.kernelModules = lib.optional (kvmModule != null) kvmModule;
    boot.kernelParams =
      [ "iommu=pt" ] ++
      (if kvmModule == "kvm-intel"
       then [ "intel_iommu=on" ]
       else if kvmModule == "kvm-amd"
       then [ "amd_iommu=on" ]
       else [ ]);

    users.users.player.extraGroups = lib.mkIf (profile == "daily") [ "libvirtd" "kvm" ];
    users.users.ghost.extraGroups = lib.mkIf (profile == "paranoid") [ "libvirtd" "kvm" ];

    environment.systemPackages = with pkgs; [
      virt-viewer
      qemu_kvm
      OVMF
      libvirt
      virt-manager
      vmClassHelper
    ];

    services.spice-vdagentd.enable = mkDefault false;
    virtualisation.spiceUSBRedirection.enable = mkDefault false;

    systemd.tmpfiles.rules = [
      "d ${storageRoot} 0750 root libvirtd - -"
      "d ${storageRoot}/base 0750 root libvirtd - -"
      "d ${storageRoot}/persistent 0750 root libvirtd - -"
      "d ${storageRoot}/transient 0750 root libvirtd - -"
    ];

    environment.etc."libvirt/repo-networks/${repoNat}.xml".source = repoNatXml;
    environment.etc."libvirt/repo-networks/${repoIsolated}.xml".source = repoIsolatedXml;

    systemd.services.repo-libvirt-networks = {
      description = "Define and start repo-managed libvirt helper networks";
      after = [ "libvirtd.service" ];
      wants = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        ensure_net() {
          local name="$1"
          local xml="$2"
          if ! ${pkgs.libvirt}/bin/virsh net-info "$name" >/dev/null 2>&1; then
            ${pkgs.libvirt}/bin/virsh net-define "$xml"
          fi
          ${pkgs.libvirt}/bin/virsh net-autostart "$name" >/dev/null 2>&1 || true
          if ! ${pkgs.libvirt}/bin/virsh net-info "$name" | ${pkgs.gnugrep}/bin/grep -q "Active:.*yes"; then
            ${pkgs.libvirt}/bin/virsh net-start "$name"
          fi
        }
        ensure_net ${escapeShellArg repoNat} ${escapeShellArg repoNatXml}
        ensure_net ${escapeShellArg repoIsolated} ${escapeShellArg repoIsolatedXml}
      '';
    };
  };
}
