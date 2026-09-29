# --- eza ---
# Modern `ls` replacement (aliases live in home/zsh.nix).
{ pkgs, ... }:
{
  home.packages = [ pkgs.eza ];
}
