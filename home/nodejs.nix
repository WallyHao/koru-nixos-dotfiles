# --- nodejs ---
# Node.js LTS (npm and corepack are bundled).
{ pkgs, ... }:
{
  home.packages = [ pkgs.nodejs_22 ];
}
