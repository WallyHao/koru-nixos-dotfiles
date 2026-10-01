# uv manages project interpreters/dependencies; Ruff remains a Nix-built binary.
# Locking uv does not lock the Python versions it downloads for projects.
{ pkgs }:
{
  packages = [
    pkgs.uv
    pkgs.ruff
  ];
  versions = {
    uv = pkgs.uv.version;
    ruff = pkgs.ruff.version;
  };
}
