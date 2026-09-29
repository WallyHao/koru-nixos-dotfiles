# --- mihomo ---
# On-demand system-wide TUN proxy. The subscription URL stays outside the flake.
#
# proxyctl drives a single Mihomo service: `refresh` fetches the subscription
# and probes every node against Google, keeping only the reachable ones,
# `start` picks one of them interactively and routes everything through it,
# `status` reports state and `shutdown` tears it down.
#
# Refs: https://wiki.metacubex.one/ (mihomo configuration and API)
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
  nodesFile = "${configDir}/nodes.tsv";
  # The wrapper, not the nix-store binary, is the one carrying the setuid bit.
  sudo = "${config.security.wrapperDir}/sudo";

  proxyctl = pkgs.writeShellApplication {
    name = "proxyctl";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      fzf
      gawk
      gnused
      iproute2
      jq
      mihomo
      systemd
    ];
    text = ''
      subscription_file=${subscriptionFile}
      secret_file=${secretFile}
      provider_file=${providerFile}
      nodes_file=${nodesFile}
      controller=127.0.0.1:9090
      api="http://$controller"

      usage() {
        cat >&2 <<'EOF'
      Usage: proxyctl <command>

        start      Pick a Google-reachable node (arrow keys + Enter) and turn
                   the global TUN proxy on through it.
        status     Show whether the proxy runs and which node is selected.
        shutdown   Stop the proxy and tear down the TUN interface.
        refresh    Re-fetch the subscription and rebuild the reachable list.
        help       Show this message.
      EOF
      }

      # Node commands talk to the loopback RESTful API; the bearer secret lives
      # in a user-readable file so they run without sudo.
      require_secret() {
        if [[ ! -f $secret_file ]]; then
          echo "Missing API secret: $secret_file (run 'proxyctl start' first)" >&2
          exit 1
        fi
        secret=$(<"$secret_file")
      }

      api_get() {
        curl -fsS -H "Authorization: Bearer $secret" "$api$1"
      }

      # Fetch the subscription ourselves: Mihomo's own provider fetch would be
      # routed through MATCH,PROXY (deadlock, no nodes yet) and its parser
      # rejects the blank first line of base64 v2ray subscriptions.
      fetch_subscription() {
        local url raw
        url=$(cat -- "$subscription_file")
        if [[ ! $url =~ ^https?://[^[:space:]]+$ ]]; then
          echo "Put one Mihomo/Clash subscription URL in $subscription_file" >&2
          return 1
        fi
        raw=$(curl -fsSL --max-time 30 -A "clash-verge/v1.0" -- "$url") || {
          echo "Failed to download subscription: $url" >&2
          return 1
        }
        if [[ $raw == *proxies:* || $raw == *proxy-groups:* ]]; then
          printf '%s\n' "$raw" > "$provider_file"
        else
          # Subscriptions are usually URL-safe, unpadded base64.
          local b64
          b64=$(printf '%s' "$raw" | tr -d '[:space:]' | tr '_-' '/+')
          case $(( ''${#b64} % 4 )) in
            1) b64=$b64=== ;;
            2) b64=$b64== ;;
            3) b64=$b64= ;;
          esac
          # Mihomo reads the trojan SNI from 'sni', but subscriptions carry it
          # as 'peer', so translate it while decoding.
          printf '%s' "$b64" | base64 -d 2>/dev/null |
            sed -E '/^trojan:\/\// s/([?&])peer=/\1sni=/g; /^[[:space:]]*$/d' > "$provider_file"
        fi
        chmod 0600 "$provider_file"
      }

      # Probe every node against Google; keep only the reachable ones, ordered
      # by latency but with US nodes first since that is the target region.
      refresh() {
        if [[ ! -f $subscription_file ]]; then
          echo "Missing subscription file: $subscription_file" >&2
          exit 1
        fi
        # A running TUN would capture the probe traffic; stop it first.
        if systemctl is-active --quiet mihomo; then
          echo "Stopping the running proxy to probe accurately ..." >&2
          ${sudo} systemctl stop mihomo
        fi
        echo "Fetching subscription ..." >&2
        fetch_subscription

        tmp=$(mktemp -d)
        pid=
        cleanup() {
          [[ -n $pid ]] && kill "$pid" 2>/dev/null
          rm -rf -- "$tmp"
        }
        trap cleanup EXIT
        cp "$provider_file" "$tmp/sub.yaml"
        cat > "$tmp/config.yaml" <<CFG
      mixed-port: 17890
      external-controller: 127.0.0.1:59777
      log-level: warning
      dns:
        enable: true
        default-nameserver: [223.5.5.5]
        proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
      proxy-providers:
        sub:
          type: file
          path: $tmp/sub.yaml
      proxy-groups:
        - {name: PROBE, type: select, use: [sub]}
      rules:
        - MATCH,PROBE
      CFG
        mihomo -d "$tmp" -f "$tmp/config.yaml" >"$tmp/log" 2>&1 &
        pid=$!
        for _ in $(seq 1 40); do
          curl -fsS http://127.0.0.1:59777/version >/dev/null 2>&1 && break
          sleep 0.25
        done
        local resp
        resp=$(curl -fsS -G --max-time 90 \
          --data-urlencode "url=https://www.google.com/generate_204" \
          --data-urlencode "timeout=5000" \
          http://127.0.0.1:59777/group/PROBE/delay) || {
          echo "Probe failed; is the subscription still valid?" >&2
          exit 1
        }
        printf '%s' "$resp" |
          jq -r 'to_entries[] | select(.value > 0) | "\(.key)\t\(.value)"' |
          awk -F'\t' '{ us = (index($1, "美国") > 0 || index($1, "🇺🇲") > 0 || index($1, "US") > 0) ? 0 : 1; print us "\t" $2 "\t" $1 }' |
          sort -k1,1n -k2,2n |
          awk -F'\t' '{ print $3 "\t" $2 }' > "$nodes_file"
        if [[ ! -s $nodes_file ]]; then
          echo "No node could reach Google." >&2
          exit 1
        fi
        echo "Google-reachable nodes: $(wc -l < "$nodes_file")" >&2
      }

      enable_node() {
        local node=$1 secret secret_json
        if [[ ! -f $secret_file ]]; then
          (umask 077; head -c 32 /dev/urandom | base64 | tr -d '\n' > "$secret_file")
          chown ${username} -- "$secret_file"
        fi
        secret=$(<"$secret_file")
        secret_json=$(printf '%s' "$secret" | jq -Rs .)
        install -d -m 0700 /etc/mihomo
        local tmp
        tmp=$(mktemp /etc/mihomo/config.yaml.XXXXXX)
        cat > "$tmp" <<CONFIG
      mode: rule
      log-level: warning
      allow-lan: false
      ipv6: true
      mixed-port: 7890
      external-controller: $controller
      secret: $secret_json
      profile:
        store-selected: true
      tun:
        enable: true
        stack: mixed
        auto-route: true
        auto-redirect: true
        auto-detect-interface: true
        strict-route: true
        dns-hijack:
          - any:53
          - tcp://any:53
      dns:
        enable: true
        ipv6: true
        enhanced-mode: fake-ip
        default-nameserver:
          - 223.5.5.5
        proxy-server-nameserver:
          - 223.5.5.5
          - 119.29.29.29
        nameserver:
          - "https://1.1.1.1/dns-query#PROXY"
      # Supplied by proxyctl as a systemd credential, so Mihomo never fetches
      # it over the (not yet working) proxy.
      proxy-providers:
        subscription:
          type: file
          path: /run/credentials/mihomo.service/subscription.yaml
          health-check:
            enable: true
            url: https://www.google.com/generate_204
            interval: 300
      proxy-groups:
        - name: PROXY
          type: select
          use: [subscription]
      # Everything goes through the selected node, i.e. effectively global.
      rules:
        - MATCH,PROXY
      CONFIG
        chmod 0600 "$tmp"
        mv -f -- "$tmp" /etc/mihomo/config.yaml
        systemctl restart mihomo
        # The API answers before the file proxy-provider has loaded, and a PUT
        # for a node not yet in the group returns 404. Wait for it to appear.
        local ready
        ready=
        for _ in $(seq 1 80); do
          if api_get /proxies/PROXY 2>/dev/null | jq -e --arg n "$node" '.all | index($n)' >/dev/null 2>&1; then
            ready=1
            break
          fi
          sleep 0.25
        done
        if [[ -z $ready ]]; then
          echo "Node never appeared; is the subscription still valid?" >&2
          exit 1
        fi
        local body
        body=$(jq -cn --arg name "$node" '{name: $name}')
        curl -fsS -X PUT -H "Authorization: Bearer $secret" \
          -H "Content-Type: application/json" --data "$body" "$api/proxies/PROXY" >/dev/null || {
          echo "Failed to select node: $node" >&2
          exit 1
        }
        echo "node: $node"
        systemctl is-active mihomo
      }

      start() {
        if [[ ! -s $nodes_file ]]; then
          echo "No node list yet; run 'proxyctl refresh' first." >&2
          exit 1
        fi
        local selection node
        selection=$(fzf --delimiter=$'\t' --with-nth=2,1 --reverse --height=60% \
          --header='↑↓ choose  Enter confirm  type 美国/US to filter' \
          --select-1 < "$nodes_file") || {
          echo "Cancelled." >&2
          exit 0
        }
        node=$(printf '%s' "$selection" | cut -f1)
        # Guard against a stale list written with the columns swapped.
        if [[ $node =~ ^[0-9]+$ ]]; then
          node=$(printf '%s' "$selection" | cut -f2)
        fi
        if [[ -z $node ]]; then
          echo "No node selected." >&2
          exit 1
        fi
        if [[ $EUID -ne 0 ]]; then
          exec ${sudo} -- "$0" __enable "$node"
        fi
        enable_node "$node"
      }

      status() {
        if systemctl is-active --quiet mihomo; then
          echo "service: active"
          require_secret
          echo "node:    $(api_get /proxies/PROXY | jq -r '.now')"
          local tun
          tun=$(ip -o link show 2>/dev/null | awk -F': ' '/[Mm]ihomo/ { print $2 }')
          [[ -n $tun ]] && echo "tun:     $tun"
        else
          echo "service: inactive"
        fi
      }

      shutdown() {
        if [[ $EUID -ne 0 ]]; then
          exec ${sudo} -- "$0" __shutdown
        fi
        systemctl stop mihomo
        echo "service: $(systemctl is-active mihomo || true)"
      }

      if [[ $# -lt 1 ]]; then
        usage
        exit 2
      fi
      case $1 in
        start) start ;;
        status) status ;;
        shutdown) shutdown ;;
        refresh) refresh ;;
        __enable) enable_node "$2" ;;
        __shutdown)
          systemctl stop mihomo
          echo "service: $(systemctl is-active mihomo || true)"
          ;;
        help | -h | --help) usage ;;
        *)
          usage
          exit 2
          ;;
      esac
    '';
  };
in
{
  services.mihomo = {
    enable = true;
    tunMode = true;
    # A runtime file, so the subscription token never enters the Nix store.
    configFile = "/etc/mihomo/config.yaml";
  };

  # Keep the TUN proxy off after boot; proxyctl explicitly starts/stops it.
  systemd.services.mihomo.wantedBy = lib.mkForce [ ];
  environment.systemPackages = [ proxyctl ];

  # Feed the normalised subscription to Mihomo's DynamicUser as a credential,
  # and let it read that provider file outside its state directory.
  systemd.services.mihomo.serviceConfig.LoadCredential = lib.mkForce [
    "config.yaml:${config.services.mihomo.configFile}"
    "subscription.yaml:${providerFile}"
  ];
  systemd.services.mihomo.serviceConfig.Environment = [
    "SAFE_PATHS=/run/credentials/mihomo.service"
  ];
}
