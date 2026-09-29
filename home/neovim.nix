# --- neovim ---
# The editor. Neovim is installed as a package rather than through
# programs.neovim so its existing out-of-repo config is left untouched; only
# $EDITOR/$VISUAL are pointed at it (helix.nix used to set defaultEditor).
{ pkgs, lib, ... }:
{
  home.packages = [ pkgs.neovim ];

  home.sessionVariables = {
    EDITOR = lib.getExe pkgs.neovim;
    VISUAL = lib.getExe pkgs.neovim;
  };
}
