# --- theme ---
# Global theme: the single source of truth for colors/fonts.
# Every tool (alacritty, btop, niri, gtk, tty, nvim, p10k, ...) references
# this file, so changing the palette here re-themes the whole system.
#
# Palette: "warm apricot" (inspired by powerlevel10k), from the current
# terminal config (~/.config/alacritty/alacritty.toml).
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
  cursor-name = "Bibata-Modern-P10K";
  cursor-size = 24;

  # --- Semantic colors ---
  # Used for backgrounds, text, accents, borders, cursor, selection.
  bg = "#1D1A16"; # primary background
  bg-alt = "#2E2A24"; # dim background (e.g. normal black)
  fg = "#D6CBBC"; # primary foreground
  fg-bright = "#D8CDBC"; # bright subset of foreground
  muted = "#C9BFAE"; # dim text (e.g. normal white)
  muted-alt = "#7D7561"; # inactive/box lines (btop boxes, git)
  accent = "#C9905F"; # accent/orange (cursor, titles, focus)
  accent-deep = "#B0684A"; # deep accent (graph starts)
  accent-bright = "#FFD08A"; # brighter accent (prompt symbol, highlights)
  accent-bg = "#3D3324"; # selection background
  cursor = "#E8DCC8"; # cursor text / selection text
  border = "#4A4138"; # inactive borders, gray tones
  urgent = "#C47A4F"; # urgent/alert
  black = "#211D10"; # deep black (e.g. focused window bg)

  # --- ANSI 16-color palette ---
  # normal (0-7)
  ansi = {
    black = "#2E2A24";
    red = "#BC6C4E";
    green = "#7C9A6E";
    yellow = "#BFA05F";
    blue = "#7E98AC";
    magenta = "#A58595";
    cyan = "#73A09E";
    white = "#C9BFAE";
  };
  # bright (8-15)
  ansi-bright = {
    black = "#443D33";
    red = "#D08A66";
    green = "#8FAF80";
    yellow = "#D4B87E";
    blue = "#9FB4C4";
    magenta = "#C3A0AE";
    cyan = "#97BDBA";
    white = "#D8CDBC";
  };
  # TTY console palette: 16 entries (8 normal + 8 bright). Tuned separately from
  # the ANSI palette above because the Linux console renders them differently
  # (black == bg on the tty); kept here so tty.nix stays theme-driven.
  console-colors = [
    "#1D1A16" # black
    "#BC6C4E" # red
    "#7D7561" # green
    "#C9905F" # yellow
    "#5E7E96" # blue
    "#A9807F" # magenta
    "#6E9B92" # cyan
    "#D6CBBC" # white
    "#554E42" # bright black
    "#C67A5B" # bright red
    "#9A9160" # bright green
    "#DBA06A" # bright yellow
    "#7D9FBA" # bright blue
    "#C69B9A" # bright magenta
    "#8AB5AB" # bright cyan
    "#F0E7DA" # bright white
  ];
}
