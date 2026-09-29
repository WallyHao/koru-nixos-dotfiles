# --- git ---
# Version control. The gh credential helper is declared here rather than
# hand-written into ~/.gitconfig: a literal /nix/store path to gh goes stale the
# moment gh is updated, while this is regenerated on every rebuild.
{ lib, pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings.credential = {
      "https://github.com".helper = "!${lib.getExe pkgs.gh} auth git-credential";
      "https://gist.github.com".helper = "!${lib.getExe pkgs.gh} auth git-credential";
    };
  };
}
