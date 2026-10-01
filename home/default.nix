# --- home/default ---
# Home-manager configuration for the user layer.
#
# home/modules-enables.nix is the single switchboard: one boolean per module in home/,
# which doubles as the inventory of what home/ can install. The switchboard must
# match the directory exactly (asserted below), so a flag can never point at a
# missing file and a file can never sit unlisted. This file and modules-enables.nix are
# the control files, not modules, so discovery skips them.
#
# Because this layer owns only user config, the flake exposes it as a switchable
# home profile output (<host>) so it can change at runtime without a system
# rebuild.
{
  config,
  lib,
  pkgs,
  username,
  theme,
  enabled ? import ./modules-enables.nix,
  ...
}:
let
  helpers = import ../lib/module-discovery.nix { inherit lib; };
  dependencies = import ../lib/home-module-dependencies.nix;

  control = [
    "default"
    "modules-enables"
  ];
  modules = lib.filterAttrs (n: _: !(builtins.elem n control)) (helpers.nixModules ./.);
  invalidFlags = builtins.filter (n: !(builtins.isBool enabled.enable.${n})) flags;
  selected =
    assert lib.assertMsg (
      invalidFlags == [ ]
    ) "home/modules-enables.nix: flags must be booleans: ${lib.concatStringsSep ", " invalidFlags}";
    builtins.filter (n: enabled.enable.${n} or false) (builtins.attrNames modules);

  # The switchboard and the directory must agree in both directions; name each
  # mismatch so the failure says which file or flag is out of place.
  allFiles = builtins.attrNames modules;
  flags = builtins.attrNames (enabled.enable or { });
  drift =
    map (n: "unlisted ${n}") (builtins.filter (n: !(builtins.elem n flags)) allFiles)
    ++ map (n: "unknown ${n}") (builtins.filter (n: !(builtins.elem n allFiles)) flags);
  missingDependencies = lib.flatten (
    lib.mapAttrsToList (
      module: requirements:
      lib.optionals (enabled.enable.${module} or false) (
        map (requirement: "${module} requires ${requirement}") (
          builtins.filter (requirement: !(enabled.enable.${requirement} or false)) requirements
        )
      )
    ) dependencies
  );
in
{
  imports = map (n: modules.${n}) selected;

  assertions = [
    {
      assertion = drift == [ ];
      message = "home/modules-enables.nix and home/ disagree: ${lib.concatStringsSep ", " drift}";
    }
    {
      assertion = missingDependencies == [ ];
      message = "invalid Home Manager module selection: ${lib.concatStringsSep ", " missingDependencies}";
    }
  ];

  warnings =
    lib.optional (
      !(enabled.enable.niri or false)
    ) "The Niri desktop is disabled; no graphical session is configured."
    ++ lib.optional (
      !(enabled.enable.tty-login or false)
    ) "TTY login no longer starts the graphical session automatically.";

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.11";

  # Installation is managed independently by `koru profile build`.
  home.sessionPath = [ "\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/koru-dev/bin" ];

  programs.home-manager.enable = true;

  # The line above installs the home-manager CLI only when home-manager runs
  # standalone. Embedded via nixos-rebuild it sets submoduleSupport.enable, and
  # the module then adds nothing, so `home-manager switch` (the <host> output)
  # would be unreachable from a fresh shell. Put the CLI in the system per-user
  # profile instead; the standalone path already gets it from the flag.
  home.packages = lib.optional config.submoduleSupport.enable pkgs.home-manager ++ [
    (import ../lib/koru-package.nix {
      inherit pkgs lib theme;
      repositoryRoot = "${config.home.homeDirectory}/.config/nixos";
    })
  ];
}
