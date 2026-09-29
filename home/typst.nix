# --- typst ---
# Typesetting system (https://typst.app); installs the `typst` CLI.
{ pkgs, ... }:
{
  home.packages = [ pkgs.typst ];
}
