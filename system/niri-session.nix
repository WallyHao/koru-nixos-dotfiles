# System Niri session registration and document-portal runtime.
{ pkgs, username, ... }:
{
  programs.niri = {
    enable = true;
    useNautilus = false;
  };
  programs.ydotool.enable = true;
  users.users.${username}.extraGroups = [ "ydotool" ];

  environment.systemPackages = [ pkgs.fuse3 ];
}
