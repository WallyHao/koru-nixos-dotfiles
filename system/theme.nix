# --- theme ---
# Global theme: the single source of truth for colors/fonts.
# Every tool (kitty, btop, niri, gtk, tty, nvim, p10k, ...) references
# this file, so changing the palette here re-themes the whole system.
#
# Palette: "Koru Fern", a low-glare green-charcoal palette with soft young-yellow
# accents. ANSI roles remain distinct for diagnostics and diffs.
{
  # --- Font ---
  font = "Maple Mono NF CN";
  # Per-surface sizes, so no tool hardcodes its own.
  font-size = 16; # terminal / editor / input method
  font-size-ui = 11; # GTK widgets
  font-size-bar = 12; # wmenu / other small UI

  # --- Cursor ---
  # One definition for the whole session: home/cursor-theme.nix recolors the
  # theme to the palette below, and home.pointerCursor propagates the name/size
  # to GTK; niri reads it through its cursor block in home/niri.nix.
  cursor-name = "Bibata-Modern-Koru";
  cursor-size = 24;

  # --- Semantic colors ---
  # Used for backgrounds, text, accents, borders, cursor, selection.
  bg = "#171E1A"; # primary background
  bg-alt = "#222D26"; # raised surfaces and panels
  fg = "#D2DCD0"; # primary foreground
  fg-bright = "#E1E8DB"; # emphasized foreground
  muted = "#A5B3A2"; # secondary readable text
  muted-alt = "#788A78"; # decoration and disabled text
  accent = "#8FBF88"; # fern green for focus and titles
  accent-yellow = "#E6D87A"; # soft young yellow for sparse UI accents
  accent-yellow-bright = "#F5E9A6"; # brighter yellow for emphasized text
  accent-deep = "#527B59"; # graph starts and decoration
  accent-bright = "#B4D6A2"; # sparse highlights
  accent-bg = "#334936"; # selection background
  cursor = "#DEE7D5"; # cursor and selection text
  border = "#425347"; # inactive borders
  urgent = "#D39B79"; # warnings and attention
  black = "#121813"; # deepest surface and text on bright accents

  # --- ANSI 16-color palette ---
  # normal (0-7)
  ansi = {
    black = "#222D26";
    red = "#CC8F88";
    green = "#8FBF88";
    yellow = "#E6D87A";
    blue = "#8EAAB8";
    magenta = "#B39BB5";
    cyan = "#88B8AB";
    white = "#D2DCD0";
  };
  # bright (8-15)
  ansi-bright = {
    black = "#526457";
    red = "#DDA39A";
    green = "#B4D6A2";
    yellow = "#F5E9A6";
    blue = "#ACC3CE";
    magenta = "#CAB5CA";
    cyan = "#A6D0C2";
    white = "#E1E8DB";
  };
  # TTY console palette: 16 entries (8 normal + 8 bright). Tuned separately from
  # the ANSI palette above because the Linux console renders them differently
  # (black == bg on the tty); kept here so tty.nix stays theme-driven.
  console-colors = [
    "#171E1A" # black
    "#CC8F88" # red
    "#8FBF88" # green
    "#E6D87A" # yellow
    "#8EAAB8" # blue
    "#B39BB5" # magenta
    "#88B8AB" # cyan
    "#D2DCD0" # white
    "#526457" # bright black
    "#DDA39A" # bright red
    "#B4D6A2" # bright green
    "#F5E9A6" # bright yellow
    "#ACC3CE" # bright blue
    "#CAB5CA" # bright magenta
    "#A6D0C2" # bright cyan
    "#E1E8DB" # bright white
  ];
}
