{
  pkgs,
  lib,
  theme,
  repositoryRoot,
}:
let
  scripts = pkgs.runCommand "koru-scripts" { } ''
    mkdir -p $out
    cp ${../scripts/koru.sh} $out/koru.sh
    cp ${../scripts/home-modules.sh} $out/home-modules.sh
    cp -r ${../scripts/koru} $out/koru
  '';
  cli = pkgs.writeShellApplication {
    name = "koru";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      diffutils
      findutils
      gawk
      git
      gnugrep
      gnused
      home-manager
      jq
      nix
      nixos-rebuild
      nixfmt
      python3
      systemd
      util-linux
    ];
    text = ''
      export KORU_REPO=${lib.escapeShellArg repositoryRoot}
      export KORU_SUDO=/run/wrappers/bin/sudo
      export KORU_COLOR_HEADING=${lib.escapeShellArg theme.accent-bright}
      export KORU_COLOR_SUCCESS=${lib.escapeShellArg theme.accent}
      export KORU_COLOR_WARNING=${lib.escapeShellArg theme.accent-yellow}
      export KORU_COLOR_ERROR=${lib.escapeShellArg theme.ansi.red}
      export KORU_COLOR_LABEL=${lib.escapeShellArg theme.muted}
      export KORU_COLOR_VALUE=${lib.escapeShellArg theme.fg}
      export KORU_COLOR_MUTED=${lib.escapeShellArg theme.muted-alt}
      exec ${pkgs.bash}/bin/bash ${scripts}/koru.sh "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "koru-cli";
  paths = [ cli ];
  postBuild = ''
    install -Dm0644 ${../completions/_koru} $out/share/zsh/site-functions/_koru
  '';
}
