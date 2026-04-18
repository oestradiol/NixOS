# Internationalisation layer — split into Japanese (fcitx5 + mozc) and
# Brazilian (locale + BR keymap + pt_BR LC_* settings) subsystems.
#
# Both default to `true` in Stage 3 because the pre-refactor repo always
# enabled them — keeping Stage 3 derivation-equivalent for the operator.
# Stage 5 flips the defaults to `false` and moves the operator's
# enablement into a gitignored `hosts/nixos/local.nix`, so published
# forks start cold.
{ config, lib, pkgs, ... }:
let
  jp = config.myOS.i18n.japanese;
  br = config.myOS.i18n.brazilian;
in {
  options.myOS.i18n = {
    japanese = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Japanese input method + fonts (fcitx5 with mozc-ut). Default:
          true (preserves pre-Stage-3 behaviour).
        '';
      };
      inputMethod.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install and enable fcitx5 with mozc-ut.";
      };
      fonts.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install CJK font coverage (reserved for Stage 3+ follow-up).";
      };
    };

    brazilian = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Brazilian Portuguese locale (pt_BR.UTF-8 LC_* categories) and
          br-abnt2 console keymap. Default: true (preserves
          pre-Stage-3 behaviour).
        '';
      };
      locale.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Apply pt_BR.UTF-8 for LC_ADDRESS/LC_TIME/LC_MONETARY/etc.";
      };
      keyboard.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Set console keyMap and XKB layout to br-abnt2/br.";
      };
    };
  };

  config = lib.mkMerge [
    # Default locale always applies (separate from BR/JP); controlled by
    # myOS.host.defaultLocale in modules/core/host.nix.
    {
      i18n.defaultLocale = config.myOS.host.defaultLocale;
    }

    # ── Brazilian layer ─────────────────────────────────────────────
    (lib.mkIf (br.enable && br.locale.enable) {
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "pt_BR.UTF-8";
        LC_IDENTIFICATION = "pt_BR.UTF-8";
        LC_MEASUREMENT = "pt_BR.UTF-8";
        LC_MONETARY = "pt_BR.UTF-8";
        LC_NAME = "pt_BR.UTF-8";
        LC_NUMERIC = "pt_BR.UTF-8";
        LC_PAPER = "pt_BR.UTF-8";
        LC_TELEPHONE = "pt_BR.UTF-8";
        LC_TIME = "pt_BR.UTF-8";
      };
    })

    (lib.mkIf (br.enable && br.keyboard.enable) {
      console.keyMap = "br-abnt2";
      environment.sessionVariables.XKB_DEFAULT_LAYOUT = "br";
    })

    # ── Japanese layer ──────────────────────────────────────────────
    (lib.mkIf (jp.enable && jp.inputMethod.enable) {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          addons = with pkgs; [
            fcitx5-mozc-ut
            fcitx5-gtk
          ];
          waylandFrontend = true;
        };
      };
    })
  ];
}
