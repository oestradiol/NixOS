# Cross-cutting option declarations only.
#
# Feature-specific options live co-located with their implementing modules
# (Stage 2 of the publication refactor). This file now only declares the
# four knobs that do not naturally belong to any single feature module:
#
#   - myOS.profile             — active system posture (paranoid / daily)
#   - myOS.gpu                 — primary GPU stack (consumed by modules/gpu/*)
#   - myOS.desktopEnvironment  — desktop pick (consumed by modules/desktop/*)
#   - myOS.persistence.root    — impermanence mount path (consumed by several
#                                 modules that build persistence/state paths)
#
# Every other `myOS.*` option is declared in the module that consumes it.
# See docs/REFACTOR-PLAN.md §6 Stage 2 for the map.
{ lib, ... }:
{
  options.myOS = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "nvidia" "amd" "none" ];
      default = "nvidia";
      description = "Primary GPU stack.";
    };

    profile = lib.mkOption {
      type = lib.types.enum [ "daily" "paranoid" ];
      default = "paranoid";
      description = "Current trust / posture profile.";
    };

    desktopEnvironment = lib.mkOption {
      type = lib.types.enum [ "plasma" "hyprland" "none" ];
      default = "plasma";
      description = "Desktop environment (plasma for KDE Plasma 6, hyprland for Hyprland, none for manual Wayland compositor setup).";
    };

    persistence.root = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Persist mount used by impermanence.";
    };
  };
}
