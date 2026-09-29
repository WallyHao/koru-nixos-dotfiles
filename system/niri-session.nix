# System Niri session registration and document-portal runtime.
{ pkgs, ... }:
{
  programs.niri = {
    enable = true;
    useNautilus = false;
  };
  environment.systemPackages = [ pkgs.fuse3 ];
}
