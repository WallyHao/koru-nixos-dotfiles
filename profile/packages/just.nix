{ pkgs }:
{
  packages = [ pkgs.just ];
  versions.just = pkgs.just.version;
}
