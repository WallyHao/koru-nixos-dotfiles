# --- codex ---
# OpenAI Codex CLI from nixpkgs. codex-relay (gronxb/codex-relay) is a
# third-party Node CLI absent from nixpkgs, so an activation step installs it
# from npm into a private prefix. That prefix's bin stays off PATH on purpose:
# codex-relay depends on @openai/codex, whose `codex` shim would otherwise
# shadow the nixpkgs build, so only a wrapper for codex-relay is exposed.
#
# The install is guarded by a version check (a no-op on later switches) and
# pins the npmmirror registry because the huaweicloud mirror in ~/.npmrc is
# unreliable from this network.
#
# Refs:
#   https://github.com/gronxb/codex-relay
{
  config,
  lib,
  pkgs,
  ...
}:
let
  prefix = "${config.home.homeDirectory}/.npm-global";
  node = "${pkgs.nodejs_22}/bin/node";
  npm = "${pkgs.nodejs_22}/bin/npm";
  relayVersion = "1.6.0";
in
{
  home.packages = [
    pkgs.codex
    (pkgs.writeShellScriptBin "codex-relay" ''
      exec ${prefix}/bin/codex-relay "$@"
    '')
  ];

  home.activation.installCodexRelay = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    relayManifest="${prefix}/lib/node_modules/codex-relay/package.json"
    installedVersion=""
    if [ -f "$relayManifest" ]; then
      installedVersion=$(${node} -p "require('$relayManifest').version" 2>/dev/null || true)
    fi
    if [ "$installedVersion" != "${relayVersion}" ]; then
      verboseEcho "Installing codex-relay@${relayVersion} into ${prefix}"
      run ${npm} install --global --prefix "${prefix}" \
        --registry https://registry.npmmirror.com \
        --no-fund --no-audit \
        "codex-relay@${relayVersion}"
    fi
  '';
}
