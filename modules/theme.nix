# System-wise fonts & theme configs
{ pkgs, ... }: {
  fonts = {
    # Avoid random fonts interfering
    enableDefaultPackages = false;

    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # Terminal + glyphs (icons)
      noto-fonts                  # Base latin sans/serif
      noto-fonts-cjk-sans         # Japanese coverage
      noto-fonts-color-emoji      # Coloured Emoji
      ipafont                     # Alternative JP fallback
    ];

    fontconfig = {
      enable = true;

      # Fallback order
      defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font" # Main terminal font
          "Noto Sans CJK JP"        # Fallback for JP
          "IPAGothic"               # Alternate JP glyphs (heart/symbol differences)
        ];

        sansSerif = [
          "Noto Sans"               # Main UI font
          "Noto Sans CJK JP"
          "IPAGothic"
        ];

        serif = [
          "Noto Serif"
          "Noto Serif CJK JP"
        ];

        emoji = [
          "Noto Color Emoji"        # Coloured Emojis
        ];
      };
    };
  };

  # Stylix for UI defaults
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };

      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };

      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };

      sizes = {
        applications = 10;
        terminal = 10;
        desktop = 10;
        popups = 10;
      };
    };
  };
}
