# --- zathura ---
# Keyboard-driven PDF viewer (vim-like keys, minimal chrome). Colors and font
# come from the global theme so it matches the rest of the desktop.
#
# Refs: https://man.archlinux.org/man/zathurarc.5
{ theme, ... }:
{
  programs.zathura = {
    enable = true;
    options = {
      font = "${theme.font} ${toString theme.font-size-bar}";
      default-bg = theme.bg;
      default-fg = theme.fg;
      statusbar-bg = theme.bg-alt;
      statusbar-fg = theme.fg;
      inputbar-bg = theme.bg;
      inputbar-fg = theme.fg-bright;
      completion-bg = theme.bg-alt;
      completion-fg = theme.fg;
      completion-highlight-bg = theme.accent;
      completion-highlight-fg = theme.black;
      highlight-color = theme.accent;
      highlight-active-color = theme.accent-bright;
      # Copying a selection should reach other apps (Wayland clipboard).
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      scroll-step = 60;
    };
  };
}
