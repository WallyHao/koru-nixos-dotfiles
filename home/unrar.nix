# --- unrar ---
# RAR extractor. Needed once for the course-provided Labsetup.rar, which uses
# the RAR7 format that 7zz cannot read.
{ pkgs, ... }:
{
  home.packages = [ pkgs.unrar ];
}
