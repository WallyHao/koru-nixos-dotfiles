# --- clipboard ---
# Clipboard history + persistence for Wayland.
#   cliphist          : stores copy history (wl-paste --watch cliphist store)
#   wl-clip-persist   : keeps the clipboard alive after the source app quits
#   cliphist-pick     : wmenu picker (Mod1+v in niri.nix) -> wl-copy
# Both daemons are systemd user services; they use the default
# graphical-session.target, which niri.service pulls in via niri-session.
{
  lib,
  pkgs,
  theme,
  ...
}:
let
  # Shared with niri.nix's launcher (lib/module-discovery.nix) so both pickers match.
  wmenu-opts = import ../lib/wmenu-style.nix { inherit lib theme; };

  cliphist-pick = pkgs.writeShellScriptBin "cliphist-pick" ''
    set -euo pipefail
    sel=$(${lib.getExe pkgs.cliphist} list | ${lib.getExe pkgs.wmenu} ${wmenu-opts}) || exit 0
    [ -n "$sel" ] || exit 0
    printf '%s\n' "$sel" | ${lib.getExe pkgs.cliphist} decode | ${lib.getExe' pkgs.wl-clipboard "wl-copy"}
  '';
in
{
  home.packages = [ cliphist-pick ];

  services.cliphist = {
    enable = true;
    # Text only: the picker has no image preview and this keeps history light.
    allowImages = false;
  };

  services.wl-clip-persist = {
    enable = true;
    clipboardType = "regular";
  };
}
