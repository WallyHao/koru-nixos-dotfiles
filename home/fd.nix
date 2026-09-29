# --- fd ---
# Modern `find` replacement; also fzf's default file/dir command.
{ pkgs, ... }:
{
  home.packages = [ pkgs.fd ];
}
