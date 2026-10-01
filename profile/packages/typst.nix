{ pkgs }:
{
  packages = [ pkgs.typst ];
  versions.typst = pkgs.typst.version;
}
