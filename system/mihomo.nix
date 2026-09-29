# --- mihomo ---
# On-demand system-wide TUN proxy. Runtime credentials and subscription data
# stay outside the Nix store; scripts/proxyctl.sh owns the CLI behavior.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  configDir = "/home/${username}/.config/mihomo";
  subscriptionFile = "${configDir}/subscription-url";
  secretFile = "${configDir}/api-secret";
  providerFile = "${configDir}/provider.yaml";
  nodesFile = "${configDir}/nodes.json";
  legacyNodesFile = "${configDir}/nodes.tsv";

  proxyctlBase = pkgs.writeShellApplication {
    name = "proxyctl";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      fzf
      gawk
      gnugrep
      gnused
      iproute2
      jq
      mihomo
      systemd
      util-linux
      websocat
    ];
    text = ''
      export PROXYCTL_CONFIG_DIR=${lib.escapeShellArg configDir}
      export PROXYCTL_SUBSCRIPTION_FILE=${lib.escapeShellArg subscriptionFile}
      export PROXYCTL_SECRET_FILE=${lib.escapeShellArg secretFile}
      export PROXYCTL_PROVIDER_FILE=${lib.escapeShellArg providerFile}
      export PROXYCTL_NODES_FILE=${lib.escapeShellArg nodesFile}
      export PROXYCTL_LEGACY_NODES_FILE=${lib.escapeShellArg legacyNodesFile}
      export PROXYCTL_SUDO=${lib.escapeShellArg "${config.security.wrapperDir}/sudo"}
      export PROXYCTL_OWNER=${lib.escapeShellArg username}
      export PROXYCTL_LATENCY_URL="https://www.google.com/generate_204"
      export PROXYCTL_SPEED_TEST_URL="https://speed.cloudflare.com/__down?bytes=10485760"
      ${builtins.readFile ../scripts/proxyctl.sh}
    '';
  };

  proxyctl = pkgs.symlinkJoin {
    name = "proxyctl-with-completion";
    paths = [ proxyctlBase ];
    postBuild = ''
      install -Dm0644 ${../completions/_proxyctl} $out/share/zsh/site-functions/_proxyctl
    '';
  };
in
{
  services.mihomo = {
    enable = true;
    tunMode = true;
    configFile = "/etc/mihomo/config.yaml";
  };

  # Keep the TUN proxy off after boot; proxyctl explicitly starts/stops it.
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];
  environment.systemPackages = [ proxyctl ];

  # Feed the normalized subscription to Mihomo's DynamicUser as a credential.
  systemd.services.mihomo.serviceConfig.LoadCredential = lib.mkForce [
    "config.yaml:${config.services.mihomo.configFile}"
    "subscription.yaml:${providerFile}"
  ];
  systemd.services.mihomo.serviceConfig.Environment = [
    "SAFE_PATHS=/run/credentials/mihomo.service"
  ];
}
