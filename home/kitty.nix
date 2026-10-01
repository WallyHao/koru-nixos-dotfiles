# --- kitty ---
# Kitty terminal configuration. The image-capable terminal is used by
# fastfetch so the Koru logo is rendered as a real PNG instead of text art.
{
  theme,
  lib,
  enabled,
  ...
}:
{
  programs.kitty = {
    enable = true;

    font = {
      name = theme.font;
      size = theme.font-size;
    };

    settings = {
      background = theme.bg;
      foreground = theme.fg;
      cursor = theme.accent;
      cursor_text_color = theme.bg;
      selection_background = theme.accent-bg;
      selection_foreground = theme.cursor;

      window_padding_width = 15;
      scrollback_lines = 10000;
      mouse_hide_wait = 0;
      enable_audio_bell = false;
      copy_on_select = "yes";
      cursor_shape = "beam";
      cursor_blink_interval = 0;

      color0 = theme.ansi.black;
      color1 = theme.ansi.red;
      color2 = theme.ansi.green;
      color3 = theme.ansi.yellow;
      color4 = theme.ansi.blue;
      color5 = theme.ansi.magenta;
      color6 = theme.ansi.cyan;
      color7 = theme.ansi.white;
      color8 = theme.ansi-bright.black;
      color9 = theme.ansi-bright.red;
      color10 = theme.ansi-bright.green;
      color11 = theme.ansi-bright.yellow;
      color12 = theme.ansi-bright.blue;
      color13 = theme.ansi-bright.magenta;
      color14 = theme.ansi-bright.cyan;
      color15 = theme.ansi-bright.white;
    };

    # Keep the existing Super+J/K/L fzf bindings: Kitty sends the same Meta
    # escape sequences that the Zsh widgets already expect.
    keybindings = lib.optionalAttrs (enabled.enable.fzf or false) {
      "super+j" = "send_text all \\x1bj";
      "super+k" = "send_text all \\x1bk";
      "super+l" = "send_text all \\x1bl";
    };
  };
}
