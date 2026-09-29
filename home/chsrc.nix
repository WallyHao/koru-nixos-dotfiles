# --- chsrc ---
# Mirror swapper. The CLI defaults to Chinese output; force English via `-en`.
# v0.2.7 shifts the dish position by one per option, so options must sit
# between the subcommand and the dish (`chsrc set -en uv`). A plain alias
# expands to `chsrc -en set uv`, where the leading -en is parsed as the
# command and rejected with "Unknown command `-en`", so a function re-injects
# the flag after the subcommand instead.
{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.chsrc ];

  programs.zsh.initContent = lib.mkAfter ''
    chsrc() {
      if (( $# == 0 )); then
        command chsrc
      else
        command chsrc "$1" -en "''${@:2}"
      fi
    }
  '';
}
