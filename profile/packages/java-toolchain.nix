{ pkgs }:
assert pkgs.lib.assertMsg (
  pkgs.lib.versions.major pkgs.jdk21.version == "21"
) "The Java profile requires JDK 21";
{
  packages = [ pkgs.jdk21 ];
  versions.jdk = pkgs.jdk21.version;
}
