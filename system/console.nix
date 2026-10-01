# --- tty ---
# Linux console (tty): terminus font + Koru Fern palette from the global theme.
{
  pkgs,
  lib,
  theme,
  ...
}:

{
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-118n.psf.gz";

  console.colors = map (lib.removePrefix "#") theme.console-colors;
}
