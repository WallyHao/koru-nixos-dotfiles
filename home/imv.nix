# --- imv ---
# Wayland-native image viewer, keyboard-driven and minimal like zathura. Colors
# and font come from the global theme so the letterbox blends with the desktop
# instead of flashing stock black.
#
# Only appearance is set here: imv's built-in binds already cover the useful
# keys (Left/Right = previous/next image, j/k/h/l = pan, +/- = zoom, q = quit,
# f = fullscreen, d = overlay), so none are redefined.
#
# Refs: https://man.archlinux.org/man/imv.5
{
  lib,
  pkgs,
  theme,
  ...
}:
let
  # imv takes a bare 6-digit hex code (no leading '#').
  hex = lib.removePrefix "#";
in
{
  home.packages = [ pkgs.imv ];

  xdg.configFile."imv/config".text = ''
    [options]
    background = ${hex theme.bg}
    overlay = true
    overlay_font = ${theme.font}:${toString theme.font-size-bar}
    overlay_text = $imv_current_file
    overlay_text_color = ${hex theme.fg}
    overlay_background_color = ${hex theme.black}
  '';
}
