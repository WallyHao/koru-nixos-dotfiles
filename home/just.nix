# --- just ---
# Command runner (https://github.com/casey/just); the nixpkgs build is compiled
# from the upstream GitHub source and served as a cached binary.
{ pkgs, ... }:
{
  home.packages = [ pkgs.just ];
}
