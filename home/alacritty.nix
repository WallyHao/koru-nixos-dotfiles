# --- alacritty ---
# Terminal emulator. All colors/fonts come from the global theme
# (system/theme.nix), so the whole palette changes from a single place.
{ theme, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = theme.font;
        };
        bold = {
          family = theme.font;
        };
        italic = {
          family = theme.font;
        };
        size = theme.font-size;
      };

      window = {
        padding = {
          x = 15;
          y = 15;
        };
        dynamic_title = true;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      mouse.hide_when_typing = true;

      # Win (Super) never reaches the shell on its own, so translate
      # Win+J/K/L into ESC j/k/l (Meta-j/k/l) here; zsh binds those to the fzf
      # widgets (see home/zsh.nix). `chars` with \uXXXX is expanded by
      # home-manager's normalizeAlacrittyEscapes into a real escape byte.
      keyboard.bindings = [
        {
          key = "J";
          mods = "Super";
          chars = "\\u001bj";
        }
        {
          key = "K";
          mods = "Super";
          chars = "\\u001bk";
        }
        {
          key = "L";
          mods = "Super";
          chars = "\\u001bl";
        }
      ];

      # Selecting text copies it to the clipboard immediately (Wayland wl-copy).
      selection.save_to_clipboard = true;

      # Beam cursor: matches the fern accent, easier to spot than a block.
      cursor.style = {
        shape = "Beam";
        blinking = "On";
      };

      colors = {
        primary = {
          background = theme.bg;
          foreground = theme.fg;
        };
        cursor = {
          text = theme.cursor;
          cursor = theme.accent;
        };
        selection = {
          text = theme.cursor;
          background = theme.accent-bg;
        };
        normal = {
          black = theme.ansi.black;
          red = theme.ansi.red;
          green = theme.ansi.green;
          yellow = theme.ansi.yellow;
          blue = theme.ansi.blue;
          magenta = theme.ansi.magenta;
          cyan = theme.ansi.cyan;
          white = theme.ansi.white;
        };
        bright = {
          black = theme.ansi-bright.black;
          red = theme.ansi-bright.red;
          green = theme.ansi-bright.green;
          yellow = theme.ansi-bright.yellow;
          blue = theme.ansi-bright.blue;
          magenta = theme.ansi-bright.magenta;
          cyan = theme.ansi-bright.cyan;
          white = theme.ansi-bright.white;
        };
      };
    };
  };
}
