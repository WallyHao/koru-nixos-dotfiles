# --- hosts ---
# Device registry: the single place that declares which machines exist and how
# each builds.
#
#   system = nixpkgs system to build for.
#
# Which home modules are installed is NOT decided here but in the user-layer
# switchboard, home/module-selection.nix (one boolean per module).
{
  koru = {
    system = "x86_64-linux";
  };
}
