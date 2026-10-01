# --- mihomo ---
# System-wide TUN proxy. Runtime credentials and subscription data stay outside
# the Nix store; scripts/proxyctl.sh owns the CLI behavior and the graphical
# session invokes its unattended Hong Kong selection in the background.
{
  config,
  lib,
  pkgs,
  theme,
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
      export PROXYCTL_OPERATION_LOCK=/run/proxyctl/operation.lock
      export PROXYCTL_SERVICE_LOCK=/run/proxyctl/service.lock
      export PROXYCTL_OWNER=${lib.escapeShellArg username}
      export PROXYCTL_LATENCY_URL=${lib.escapeShellArg config.koru.proxy.latencyUrl}
      export PROXYCTL_SPEED_TEST_URL="https://speed.cloudflare.com/__down?bytes=10485760"
      export PROXYCTL_COLOR_HEADING=${lib.escapeShellArg theme.accent-bright}
      export PROXYCTL_COLOR_SUCCESS=${lib.escapeShellArg theme.accent}
      export PROXYCTL_COLOR_WARNING=${lib.escapeShellArg theme.accent-yellow}
      export PROXYCTL_COLOR_ERROR=${lib.escapeShellArg theme.ansi.red}
      export PROXYCTL_COLOR_LABEL=${lib.escapeShellArg theme.muted}
      export PROXYCTL_COLOR_VALUE=${lib.escapeShellArg theme.fg}
      export PROXYCTL_COLOR_MUTED=${lib.escapeShellArg theme.muted-alt}
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
  options.koru.proxy.latencyUrl = lib.mkOption {
    type = lib.types.str;
    default = "https://www.google.com/generate_204";
    description = "HTTP endpoint used to measure proxy node latency.";
  };

  config = {
    systemd.tmpfiles.rules = [
      "d /run/proxyctl 0755 root root -"
      "f /run/proxyctl/operation.lock 0600 ${username} users -"
      "f /run/proxyctl/service.lock 0600 root root -"
    ];

    services.mihomo = {
      enable = true;
      tunMode = true;
      configFile = "/etc/mihomo/config.yaml";
    };

    # Keep the TUN proxy off after boot; proxyctl explicitly starts/stops it.
    systemd.services.mihomo.wantedBy = lib.mkForce [ ];
    environment.systemPackages = [ proxyctl ];

    # proxyctl re-invokes itself through sudo (`sudo <proxyctl> __enable NODE`)
    # to install the selected node and restart Mihomo. The graphical session
    # autostarts it without a terminal, so that one internal subcommand must not
    # prompt for a password. Both the stable /run path and the resolved store
    # path are listed because sudo may or may not follow the symlink chain when
    # matching; every other proxyctl operation keeps the normal sudo prompt.
    security.sudo.extraRules = [
      {
        users = [ username ];
        commands = [
          {
            command = "/run/current-system/sw/bin/proxyctl __enable *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${lib.getExe proxyctlBase} __enable *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Feed the normalized subscription to Mihomo's DynamicUser as a credential.
    systemd.services.mihomo.serviceConfig.LoadCredential = lib.mkForce [
      "config.yaml:${config.services.mihomo.configFile}"
      "subscription.yaml:${providerFile}"
    ];
    systemd.services.mihomo.serviceConfig.Environment = [
      "SAFE_PATHS=/run/credentials/mihomo.service"
    ];
  };
}
