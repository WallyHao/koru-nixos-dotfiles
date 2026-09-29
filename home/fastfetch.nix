# --- fastfetch ---
# On-demand system info with a small static Koru fern mark. The logo is plain
# text: it adds no animation, daemon or continuous rendering.
{ theme, ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "data";
        source = ''
                   __
                __/ /
             __/ /_/
           _/ /_/
          /_/
        '';
        color."1" = theme.accent;
        padding.right = 2;
      };
      display.separator = "  ";
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "wm"
        "cpu"
        "gpu"
        "memory"
        "disk"
        "localip"
        "battery"
        "sound"
        "brightness"
        "colors"
      ];
    };
  };
}
