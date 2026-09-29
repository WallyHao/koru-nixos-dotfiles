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

  # 1080p on the internal panel from boot.
  boot.kernelParams = [ "video=1920x1080" ];
}
