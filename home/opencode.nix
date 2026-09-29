# --- opencode ---
# AI coding agent, installed from the opencode flake input. The global
# AGENTS.md lives in home/dotfiles/opencode/ and is linked into
# ~/.config/opencode/ so the repo stays the source of truth.
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file.".config/opencode/AGENTS.md".source = ./dotfiles/opencode/AGENTS.md;
}
