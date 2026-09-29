# --- libreoffice ---
# Full office suite (Writer/Impress/Calc); also converts docx/pptx to pdf via
# `soffice --headless --convert-to pdf --outdir <dir> <file>`.
{ pkgs, ... }:
{
  home.packages = [ pkgs.libreoffice ];
}
