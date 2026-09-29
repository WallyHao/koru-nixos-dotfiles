# --- unzip ---
# Extract .zip archives (companion to the zip packer).
{ pkgs, ... }:
{
  home.packages = [ pkgs.unzip ];
}
