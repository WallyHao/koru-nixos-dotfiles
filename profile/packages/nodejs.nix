{ pkgs }:
assert pkgs.lib.assertMsg (
  pkgs.lib.versions.major pkgs.nodejs_22.version == "22"
) "The Node.js profile requires Node.js 22";
{
  packages = [ pkgs.nodejs_22 ];
  versions.nodejs = pkgs.nodejs_22.version;
}
