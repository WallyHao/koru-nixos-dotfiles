# --- gh ---
# GitHub CLI.
{ pkgs, ... }:
{
  home.packages = [ pkgs.gh ];
}
