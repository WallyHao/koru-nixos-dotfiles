# --- jq ---
# JSON processor (handy in the shell; power-profile uses a pinned copy from the
# system layer).
{ pkgs, ... }:
{
  home.packages = [ pkgs.jq ];
}
