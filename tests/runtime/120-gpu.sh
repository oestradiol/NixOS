#!/usr/bin/env bash
# Runtime: NVIDIA GPU stack. Driver loaded, modesetting on, 32-bit graphics.
source "${BASH_SOURCE%/*}/../lib/common.sh"

describe "NVIDIA kernel modules loaded"
for m in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
  assert_module_loaded "$m"
done

describe "DRM modesetting"
# /sys/module/nvidia_drm/parameters/modeset is root-readable (0400). Use sudo
# when available; otherwise fall back to checking the kernel cmdline param.
if [[ -e /sys/module/nvidia_drm/parameters/modeset ]]; then
  if [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null; then
    modeset=$(sudo -n cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || true)
    if [[ "$modeset" == "Y" ]]; then
      pass "nvidia_drm modeset=Y"
    else
      fail "nvidia_drm modeset = $modeset (expected Y)"
    fi
  elif grep -qw 'nvidia_drm.modeset=1' /proc/cmdline \
     || grep -qw 'nvidia-drm.modeset=1' /proc/cmdline; then
    pass "nvidia_drm.modeset=1 on /proc/cmdline (proxy for modeset=Y)"
  else
    skip "nvidia_drm/parameters/modeset is root-only and no sudo"
  fi
else
  fail "nvidia_drm parameters missing"
fi

describe "GPU devices present"
for d in /dev/nvidiactl /dev/nvidia0 /dev/nvidia-modeset /dev/nvidia-uvm; do
  if [[ -e "$d" ]]; then
    pass "$d exists"
  else
    warn "$d missing (GPU not yet initialized?)"
  fi
done

describe "graphics acceleration libraries"
# 32-bit + 64-bit graphics drivers under /run/current-system/sw or /run/opengl-driver
if [[ -d /run/opengl-driver/lib/dri ]] || [[ -d /run/current-system/sw/lib/dri ]]; then
  pass "dri driver dir present"
else
  warn "no DRI driver dir (expected /run/opengl-driver/lib/dri)"
fi
if [[ -d /run/opengl-driver-32/lib ]]; then
  pass "32-bit graphics driver path present"
else
  warn "/run/opengl-driver-32/lib not present (enable32Bit may need a rebuild)"
fi

describe "Vulkan/EGL probe"
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi -L 2>/dev/null | grep -q 'GPU 0'; then
    pass "nvidia-smi reports a GPU"
  else
    fail "nvidia-smi did not list any GPU"
  fi
fi
if command -v glxinfo >/dev/null 2>&1; then
  if glxinfo -B 2>/dev/null | grep -q 'NVIDIA'; then
    pass "glxinfo reports NVIDIA renderer"
  else
    info "glxinfo did not find NVIDIA renderer (may require running Wayland/X session)"
  fi
fi

describe "NIXOS_OZONE_WL + LIBVA_DRIVER_NAME env"
if [[ "${NIXOS_OZONE_WL:-}" == "1" ]]; then
  pass "NIXOS_OZONE_WL=1 exported"
else
  # check system-level env
  if grep -Rq 'NIXOS_OZONE_WL' /etc/ 2>/dev/null \
     || grep -Rq 'NIXOS_OZONE_WL' /run/current-system/etc/ 2>/dev/null; then
    pass "NIXOS_OZONE_WL set system-wide"
  else
    warn "NIXOS_OZONE_WL not observable"
  fi
fi
if [[ "${LIBVA_DRIVER_NAME:-}" == "nvidia" ]]; then
  pass "LIBVA_DRIVER_NAME=nvidia exported"
else
  if grep -Rq 'LIBVA_DRIVER_NAME.*nvidia' /etc/ /run/current-system/etc/ 2>/dev/null; then
    pass "LIBVA_DRIVER_NAME=nvidia set system-wide"
  else
    warn "LIBVA_DRIVER_NAME not observable"
  fi
fi

describe "NVIDIA powerManagement aligned with sleep policy (both off)"
profile=$(detect_profile)
# allowSleep=false → nvidia.powerManagement.enable = false.
# Check /etc/modprobe.d for NVIDIA PM param — if disabled, NVreg_DynamicPowerManagement=0x00 is NOT forced.
if grep -R 'NVreg_DynamicPowerManagement' /etc/modprobe.d/ 2>/dev/null | grep -vq '0x00'; then
  fail "NVIDIA dynamic PM enabled but allowSleep=false policy says off"
else
  pass "NVIDIA dynamic PM not enabled (matches allowSleep=false)"
fi
