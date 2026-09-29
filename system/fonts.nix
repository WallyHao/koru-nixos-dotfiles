# --- fonts ---
# Fonts. Maple Mono NF-CN is the global theme font and stays the monospace
# default. sans-serif / serif are proper proportional families instead of being
# aliased to the mono font, so UI text (GTK, browser) reads comfortably.
#
# NOTE: a few apps with their own text renderers (e.g. Electron/Chromium-style
# stacks) ignore the fontconfig hinting/subpixel settings below; they still
# sharpen alacritty, GTK and most native toolkits.
{ pkgs, theme, ... }:

{
  fonts.packages = with pkgs; [
    maple-mono.NF-CN
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  fonts.fontconfig = {
    antialias = true;
    hinting = {
      enable = true;
      style = "slight";
    };
    # RGB subpixel rendering. If text shows colour fringing, switch to "bgr".
    subpixel = {
      rgba = "rgb";
      lcdfilter = "default";
    };
    defaultFonts = {
      monospace = [ theme.font ];
      sansSerif = [
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      serif = [
        "Noto Serif"
        "Noto Serif CJK SC"
      ];
    };
  };
}
