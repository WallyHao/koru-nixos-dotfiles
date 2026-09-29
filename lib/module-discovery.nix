# Discover direct-child Nix modules for the Home Manager selection table.
# Nested feature helpers are imported by their owning module, not discovered.
{ lib }:
rec {
  # *.nix files directly in `dir`, as paths, sorted by name.
  nixFiles =
    dir:
    map (n: dir + "/${n}") (
      builtins.attrNames (
        lib.filterAttrs (n: type: type == "regular" && lib.hasSuffix ".nix" n) (builtins.readDir dir)
      )
    );

  # Same, keyed by module name (the filename without its .nix suffix).
  nixModules =
    dir:
    lib.listToAttrs (
      map (p: lib.nameValuePair (lib.removeSuffix ".nix" (baseNameOf p)) p) (nixFiles dir)
    );

}
