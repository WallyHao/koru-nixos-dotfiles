# --- ruff ---
# Python linter and formatter (Rust). Installed from nixpkgs because the PyPI
# wheel is a dynamically linked generic-linux binary, which NixOS cannot run.
{ pkgs, ... }:
{
  home.packages = [ pkgs.ruff ];
}
