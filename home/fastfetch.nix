# --- fastfetch ---
# Koru Fern system card for the half-width startup dashboard. Kitty renders the
# supplied transparent PNG, while the system data stays in a vertical card.
{ theme, ... }:
let
  # Use the supplied artwork directly, preserving its colours and alpha channel.
  logo-png = ../assets/fastfetch/koru-logo.png;

  # Match the full 66-column width used by the CPU line and card separators.
  separatorDashes = builtins.concatStringsSep "" (builtins.genList (_: "-") 66);
in
{
  xdg.configFile."fastfetch/koru-logo.png".source = logo-png;

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        # "kitty" silently renders no image on kitty 0.48 (fastfetch 2.67);
        # "kitty-direct" embeds the pixels in the escape and works.
        type = "kitty-direct";
        source = "${logo-png}";
        # The supplied PNG has a transparent square canvas.
        # Set only the width so fastfetch derives the height from the square
        # source instead of stretching it into a fixed rectangle.
        width = 30;
        position = "top";
        padding.left = 19;
        padding.bottom = 0;
      };

      display = {
        separator = "  ";
        key.width = 12;
      };

      modules = [
        {
          type = "title";
          format = "{#3}{user-name}{#} @ {#2}{host-name}{#}";
          keyColor = theme.accent-yellow;
          outputColor = theme.fg;
        }
        {
          type = "custom";
          format = "{#2}${separatorDashes}{#}";
        }
        {
          type = "os";
          key = "OS";
          keyColor = theme.accent;
          outputColor = theme.fg;
        }
        {
          type = "kernel";
          key = "Kernel";
          keyColor = theme.accent;
          outputColor = theme.fg;
        }
        {
          type = "uptime";
          key = "Uptime";
          keyColor = theme.accent;
          outputColor = theme.fg;
        }
        {
          type = "packages";
          key = "Packages";
          keyColor = theme.accent-yellow;
          outputColor = theme.fg;
        }
        {
          type = "shell";
          key = "Shell";
          keyColor = theme.accent-yellow;
          outputColor = theme.fg;
        }
        {
          type = "brightness";
          key = "Brightness";
          keyColor = theme.accent-yellow;
          outputColor = theme.fg;
        }
        {
          type = "cpu";
          key = "CPU";
          keyColor = theme.ansi.cyan;
          outputColor = theme.fg;
        }
        {
          type = "memory";
          key = "Memory";
          keyColor = theme.ansi.cyan;
          outputColor = theme.fg;
        }
        {
          type = "disk";
          key = "Disk";
          keyColor = theme.ansi.cyan;
          outputColor = theme.fg;
        }
        {
          type = "battery";
          key = "Battery";
          keyColor = theme.accent-yellow;
          outputColor = theme.fg;
        }
        {
          type = "localip";
          key = "Network";
          keyColor = theme.ansi.cyan;
          outputColor = theme.fg;
        }
        {
          type = "custom";
          format = "{#2}${separatorDashes}{#}";
        }
        {
          type = "colors";
          symbol = "circle";
          keyColor = theme.muted;
        }
      ];
    };
  };
}
