# --- field notes ---
# On-demand power snapshots for reproducible battery comparisons. The command
# only reads current state unless the user explicitly records a labeled note.
{ pkgs, ... }:
let
  field-notes = pkgs.writeShellApplication {
    name = "field-notes";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      jq
      networkmanager
      niri
    ];
    text = builtins.readFile ../scripts/field-notes.sh;
  };
in
{
  home.packages = [ field-notes ];
}
