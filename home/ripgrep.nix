# --- ripgrep ---
# Modern `grep` replacement.
{ pkgs, ... }:
{
  home.packages = [ pkgs.ripgrep ];
}
