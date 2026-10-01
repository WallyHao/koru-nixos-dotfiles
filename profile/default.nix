# Explicit install inventory. Each entry owns its packages and version metadata.
{ pkgs, rosPkgs }:
{
  c-cpp-toolchain = import ./packages/c-cpp-toolchain.nix { inherit pkgs; };
  java-toolchain = import ./packages/java-toolchain.nix { inherit pkgs; };
  just = import ./packages/just.nix { inherit pkgs; };
  nodejs = import ./packages/nodejs.nix { inherit pkgs; };
  openmpi = import ./packages/openmpi.nix { inherit pkgs; };
  python = import ./packages/python.nix { inherit pkgs; };
  ros2 = import ./packages/ros2.nix { inherit rosPkgs; };
  rust = import ./packages/rust.nix { inherit pkgs; };
  typst = import ./packages/typst.nix { inherit pkgs; };
}
