# Shared wmenu arguments derived from the palette.
{ lib, theme }:
let
  hex = lib.removePrefix "#";
in
"-f \"${theme.font} ${toString theme.font-size-bar}\" -N ${hex theme.bg} -n ${hex theme.fg} -M ${hex theme.black} -m ${hex theme.accent} -S ${hex theme.accent} -s ${hex theme.bg}"
