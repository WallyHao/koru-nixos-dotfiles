# --- uv ---
# Python package/project manager; it also downloads Python toolchains on demand,
# so no separate python3 is needed here.
{ pkgs, ... }:
{
  home.packages = [ pkgs.uv ];
}
