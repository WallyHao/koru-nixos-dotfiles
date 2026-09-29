#!/usr/bin/env bash
# This file is embedded by system/mihomo.nix into a writeShellApplication.
set -euo pipefail

config_dir=${PROXYCTL_CONFIG_DIR:?}
subscription_file=${PROXYCTL_SUBSCRIPTION_FILE:?}
secret_file=${PROXYCTL_SECRET_FILE:?}
provider_file=${PROXYCTL_PROVIDER_FILE:?}
nodes_file=${PROXYCTL_NODES_FILE:?}
legacy_nodes_file=${PROXYCTL_LEGACY_NODES_FILE:?}
sudo_command=${PROXYCTL_SUDO:?}
config_owner=${PROXYCTL_OWNER:?}
latency_url=${PROXYCTL_LATENCY_URL:-https://www.google.com/generate_204}
speed_test_url=${PROXYCTL_SPEED_TEST_URL:-https://speed.cloudflare.com/__down?bytes=10485760}
controller=127.0.0.1:9090
api=http://$controller
color_policy=auto

temporary_paths=()
background_pids=()
restore_pending=false
restore_node=

cleanup() {
  local status=$? path pid
  trap - EXIT INT TERM
  for pid in "${background_pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  for path in "${temporary_paths[@]}"; do
    [[ -e $path ]] && rm -rf -- "$path"
  done
  if [[ $restore_pending == true && -n $restore_node ]]; then
    printf '%s\n' 'Refresh did not finish; attempting to restore the previous proxy node.' >&2
    "$sudo_command" -- "$0" __enable "$restore_node" >/dev/null ||
      printf '%s\n' 'Could not restore the previous proxy automatically.' >&2
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

usage() {
  cat <<'EOF'
Usage: proxyctl [--color auto|always|never] <command> [options]

  start [--node NAME]  Start the TUN proxy using a cached node.
  status [MEASUREMENT] Show service, controller, TUN and cache state.
  nodes                List locally cached usable nodes and cached latency.
  refresh [--restore]  Refresh the subscription and reachable-node cache.
  shutdown             Stop the service and TUN interface.
  help                 Show this help.

Status measurements (explicit and mutually exclusive):
  --latency             Sample current-node HTTP delay three times.
  --traffic             Sample existing upload/download traffic rates.
  --speed-test          Download at most 10 MiB for at most 15 seconds.
  --json                Emit parseable JSON; diagnostics remain on stderr.

Refresh interrupts an active TUN. It refuses to do so unless --restore is
given, in which case it attempts to restore the previous node afterward.
EOF
}

die_usage() {
  printf 'Error: %s\n' "$*" >&2
  usage >&2
  exit 2
}

configure_colors() {
  local enabled=false
  case $color_policy in
    always) enabled=true ;;
    never) ;;
    auto)
      [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-} != dumb ]] && enabled=true
      ;;
    *) die_usage "invalid color policy '$color_policy'" ;;
  esac
  if [[ $enabled == true ]]; then
    c_heading=$'\033[38;2;180;214;162m'
    c_success=$'\033[38;2;143;191;136m'
    c_reset=$'\033[0m'
  else
    c_heading=''
    c_success=''
    c_reset=''
  fi
}

safe_display() {
  jq -nr --arg value "$1" '$value | gsub("[\\x00-\\x1F\\x7F]"; "?")'
}

ensure_runtime_dir() {
  install -d -m 0700 -- "$config_dir"
}

load_secret() {
  if [[ ! -r $secret_file ]]; then
    printf 'Missing API secret: %s\n' "$secret_file" >&2
    return 1
  fi
  secret=$(<"$secret_file")
  [[ -n $secret ]] || {
    printf '%s\n' 'The API secret file is empty.' >&2
    return 1
  }
}

api_get() {
  local path=$1
  curl --fail --silent --show-error \
    --connect-timeout 2 --max-time 5 --retry 0 \
    -H "Authorization: Bearer $secret" -- "$api$path"
}

cache_json() {
  if [[ -r $nodes_file ]] && jq -e '
    type == "array" and all(.[]; (.name | type == "string") and (.latency_ms | type == "number"))
  ' "$nodes_file" >/dev/null 2>&1; then
    cat -- "$nodes_file"
    return 0
  fi
  if [[ -r $legacy_nodes_file ]]; then
    jq -Rn '[inputs | split("\t") | select(length >= 2) |
      {name: .[0], latency_ms: (.[1] | tonumber)}]' < "$legacy_nodes_file"
    return 0
  fi
  return 1
}

cache_age_seconds() {
  local cache=$nodes_file
  [[ -e $cache ]] || cache=$legacy_nodes_file
  [[ -e $cache ]] || return 1
  local now modified
  now=$(date +%s)
  modified=$(stat -c %Y -- "$cache")
  printf '%s\n' "$((now - modified))"
}

format_age() {
  local seconds=$1
  if ((seconds < 60)); then
    printf '%s seconds' "$seconds"
  elif ((seconds < 3600)); then
    printf '%s minutes' "$((seconds / 60))"
  elif ((seconds < 86400)); then
    printf '%s hours' "$((seconds / 3600))"
  else
    printf '%s days' "$((seconds / 86400))"
  fi
}

fetch_subscription() {
  local destination=$1 url raw normalized b64
  [[ -r $subscription_file ]] || {
    printf 'Missing subscription file: %s\n' "$subscription_file" >&2
    return 1
  }
  IFS= read -r url < "$subscription_file"
  [[ $url =~ ^https?://[^[:space:]]+$ ]] || {
    printf 'Put one HTTPS Mihomo/Clash subscription URL in %s\n' "$subscription_file" >&2
    return 1
  }
  raw=$(mktemp "${TMPDIR:-/tmp}/proxyctl-subscription.XXXXXXXX")
  normalized=$(mktemp "${TMPDIR:-/tmp}/proxyctl-provider.XXXXXXXX")
  temporary_paths+=("$raw" "$normalized")
  if ! curl --fail --silent --show-error --location --max-time 30 --retry 0 \
    --user-agent 'clash-verge/v1.0' --output "$raw" -- "$url" 2>/dev/null; then
    printf '%s\n' 'Subscription download failed; the credential-bearing URL was hidden.' >&2
    return 1
  fi
  if grep -Eq '^(proxies|proxy-groups):' "$raw"; then
    sed '/^[[:space:]]*$/d' "$raw" > "$normalized"
  else
    b64=$(tr -d '[:space:]' < "$raw" | tr '_-' '/+')
    case $((${#b64} % 4)) in
      1) b64=$b64=== ;;
      2) b64=$b64== ;;
      3) b64=$b64= ;;
    esac
    if ! printf '%s' "$b64" | base64 --decode 2>/dev/null |
      sed -E '/^trojan:\/\// s/([?&])peer=/\1sni=/g; /^[[:space:]]*$/d' > "$normalized"; then
      printf '%s\n' 'Subscription parsing failed.' >&2
      return 1
    fi
  fi
  [[ -s $normalized ]] || {
    printf '%s\n' 'Subscription parsing produced no nodes.' >&2
    return 1
  }
  cp -- "$normalized" "$destination"
}

write_service_config() {
  local node=$1 secret_json temporary_config
  ensure_runtime_dir
  if [[ ! -s $secret_file ]]; then
    (umask 077; head -c 32 /dev/urandom | base64 | tr -d '\n' > "$secret_file")
    chown "$config_owner" -- "$secret_file"
  fi
  secret=$(<"$secret_file")
  secret_json=$(printf '%s' "$secret" | jq -Rs .)
  install -d -m 0700 /etc/mihomo
  temporary_config=$(mktemp /etc/mihomo/config.yaml.XXXXXXXX)
  cat > "$temporary_config" <<CONFIG
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
  interface-name: mihomo
  stack: mixed
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  strict-route: true
  dns-hijack: [any:53, tcp://any:53]
dns:
  enable: true
  ipv6: true
  enhanced-mode: fake-ip
  default-nameserver: [223.5.5.5]
  proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
  nameserver: ["https://1.1.1.1/dns-query#PROXY"]
proxy-providers:
  subscription:
    type: file
    path: /run/credentials/mihomo.service/subscription.yaml
    health-check:
      enable: true
      url: $latency_url
      interval: 300
proxy-groups:
  - name: PROXY
    type: select
    use: [subscription]
rules:
  - MATCH,PROXY
CONFIG
  chmod 0600 "$temporary_config"
  mv -- "$temporary_config" /etc/mihomo/config.yaml
  printf '%s\n' "$node" >/dev/null
}

enable_node() {
  local node=${1:-}
  [[ $EUID -eq 0 ]] || die_usage 'internal enable command requires root'
  [[ -n $node && $# == 1 ]] || die_usage 'internal enable command requires one node'
  [[ -s $provider_file ]] || {
    printf '%s\n' 'No valid provider cache; run proxyctl refresh first.' >&2
    return 1
  }
  write_service_config "$node"
  systemctl restart mihomo
  local ready=false response body
  for _ in $(seq 1 80); do
    if response=$(api_get /proxies/PROXY 2>/dev/null) &&
      jq -e --arg node "$node" '.all | index($node)' <<< "$response" >/dev/null; then
      ready=true
      break
    fi
    sleep 0.25
  done
  [[ $ready == true ]] || {
    printf '%s\n' 'The selected node did not appear in the Mihomo provider.' >&2
    return 1
  }
  body=$(jq -cn --arg name "$node" '{name: $name}')
  if ! curl --fail --silent --show-error --connect-timeout 2 --max-time 5 --retry 0 \
    -X PUT -H "Authorization: Bearer $secret" -H 'Content-Type: application/json' \
    --data "$body" -- "$api/proxies/PROXY" >/dev/null; then
    printf '%s\n' 'Mihomo rejected the requested node.' >&2
    return 1
  fi
  printf 'Node: %s\n' "$(safe_display "$node")"
  printf 'Service: %s\n' "$(systemctl is-active mihomo || true)"
}

start_node() {
  local node=$1
  if [[ $EUID -ne 0 ]]; then
    exec "$sudo_command" -- "$0" __enable "$node"
  fi
  enable_node "$node"
}

select_node() {
  local requested=${1:-} cache selection index
  cache=$(cache_json) || {
    printf '%s\n' 'No usable node cache; run proxyctl refresh first.' >&2
    return 1
  }
  if [[ -n $requested ]]; then
    jq -e --arg name "$requested" 'any(.[]; .name == $name)' <<< "$cache" >/dev/null || {
      printf 'Node is not in the local cache: %s\n' "$(safe_display "$requested")" >&2
      return 1
    }
    printf '%s\n' "$requested"
    return 0
  fi
  selection=$(jq -r 'to_entries[] |
    [.key, ((.value.latency_ms | tostring) + " ms"),
     (.value.name | gsub("[\\x00-\\x1F\\x7F]"; "?"))] | @tsv' <<< "$cache" |
    fzf --delimiter=$'\t' --with-nth=2,3 --reverse --height=60% \
      --header='Latency  Node — arrows move, Enter selects' --select-1) || return 130
  index=${selection%%$'\t'*}
  jq -r --argjson index "$index" '.[$index].name' <<< "$cache"
}

start_command() {
  local requested=
  while (($#)); do
    case $1 in
      --node) (($# >= 2)) || die_usage '--node requires a name'; requested=$2; shift 2 ;;
      *) die_usage "unknown start option '$1'" ;;
    esac
  done
  local node
  node=$(select_node "$requested") || {
    local status=$?
    [[ $status == 130 ]] && printf '%s\n' 'Node selection cancelled.' >&2
    return "$status"
  }
  start_node "$node"
}

nodes_command() {
  (($# == 0)) || die_usage 'nodes takes no arguments'
  local cache
  cache=$(cache_json) || {
    printf '%s\n' 'No usable node cache; run proxyctl refresh first.' >&2
    return 1
  }
  printf '%-10s  %s\n' 'LATENCY' 'NODE'
  jq -r '.[] | [((.latency_ms | tostring) + " ms"),
    (.name | gsub("[\\x00-\\x1F\\x7F]"; "?"))] | @tsv' <<< "$cache" |
    awk -F '\t' '{ printf "%-10s  %s\n", $1, $2 }'
}

refresh_command() {
  local restore=false
  while (($#)); do
    case $1 in
      --restore) restore=true; shift ;;
      *) die_usage "unknown refresh option '$1'" ;;
    esac
  done
  ensure_runtime_dir
  local was_active=false previous_node='' temporary_dir probe_pid response total reachable failed
  if systemctl is-active --quiet mihomo; then
    was_active=true
    [[ $restore == true ]] || {
      printf '%s\n' 'Refresh interrupts the active TUN; re-run with --restore to restore it afterward.' >&2
      return 1
    }
    if load_secret; then
      previous_node=$(api_get /proxies/PROXY 2>/dev/null | jq -r '.now // empty')
    fi
    [[ -n $previous_node ]] || {
      printf '%s\n' 'Cannot identify the active node, so safe restore is unavailable.' >&2
      return 1
    }
    restore_pending=true
    restore_node=$previous_node
    printf '%s\n' 'Stopping the active proxy; it will be restored after refresh.' >&2
    "$sudo_command" systemctl stop mihomo
  fi

  temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/proxyctl-refresh.XXXXXXXX")
  temporary_paths+=("$temporary_dir")
  printf '%s\n' 'Fetch: downloading subscription ...' >&2
  fetch_subscription "$temporary_dir/provider.yaml"
  printf '%s\n' 'Parse: subscription normalized.' >&2
  cat > "$temporary_dir/config.yaml" <<CONFIG
mixed-port: 17890
external-controller: 127.0.0.1:59777
log-level: warning
dns:
  enable: true
  default-nameserver: [223.5.5.5]
  proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
proxy-providers:
  sub: {type: file, path: $temporary_dir/provider.yaml}
proxy-groups:
  - {name: PROBE, type: select, use: [sub]}
rules:
  - MATCH,PROBE
CONFIG
  mihomo -d "$temporary_dir" -f "$temporary_dir/config.yaml" >"$temporary_dir/mihomo.log" 2>&1 &
  probe_pid=$!
  background_pids+=("$probe_pid")
  local ready=false
  for _ in $(seq 1 40); do
    if curl --fail --silent --connect-timeout 1 --max-time 1 --retry 0 \
      http://127.0.0.1:59777/version >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 0.25
  done
  [[ $ready == true ]] || {
    printf '%s\n' 'Probe: temporary Mihomo controller did not start.' >&2
    return 1
  }
  total=$(curl --fail --silent --connect-timeout 2 --max-time 5 --retry 0 \
    http://127.0.0.1:59777/proxies/PROBE | jq '.all | length')
  printf 'Probe: testing %s nodes ...\n' "$total" >&2
  response=$(curl --fail --silent --show-error -G --connect-timeout 2 --max-time 90 --retry 0 \
    --data-urlencode "url=$latency_url" --data-urlencode 'timeout=5000' \
    http://127.0.0.1:59777/group/PROBE/delay) || {
    printf '%s\n' 'Probe: node delay request failed.' >&2
    return 1
  }
  jq '[to_entries[] | select(.value | type == "number" and . > 0) |
    {name: .key, latency_ms: .value, us: (.key | test("美国|🇺🇲|(^|[^A-Za-z])US([^A-Za-z]|$)"; "i"))}] |
    sort_by(if .us then 0 else 1 end, .latency_ms) |
    map(del(.us))' <<< "$response" > "$temporary_dir/nodes.json"
  reachable=$(jq 'length' "$temporary_dir/nodes.json")
  failed=$((total - reachable))
  ((reachable > 0)) || {
    printf 'Probe: 0 reachable, %s failed; old cache preserved.\n' "$failed" >&2
    return 1
  }

  local provider_target nodes_target
  provider_target=$(mktemp "$config_dir/.provider.yaml.XXXXXXXX")
  nodes_target=$(mktemp "$config_dir/.nodes.json.XXXXXXXX")
  temporary_paths+=("$provider_target" "$nodes_target")
  install -m 0600 "$temporary_dir/provider.yaml" "$provider_target"
  install -m 0600 "$temporary_dir/nodes.json" "$nodes_target"
  mv -- "$provider_target" "$provider_file"
  mv -- "$nodes_target" "$nodes_file"
  printf 'Cache: wrote %s reachable nodes; %s failed.\n' "$reachable" "$failed" >&2

  if [[ $was_active == true ]]; then
    "$sudo_command" -- "$0" __enable "$previous_node"
    restore_pending=false
    printf 'Service: restored node %s.\n' "$(safe_display "$previous_node")" >&2
  else
    printf '%s\n' 'Service: remained inactive.' >&2
  fi
}

latency_measurement() {
  local node=$1 encoded response delay successes=0 failures=0 sum=0
  encoded=$(jq -rn --arg value "$node" '$value | @uri')
  for _ in 1 2 3; do
    if response=$(curl --fail --silent --show-error -G --connect-timeout 2 --max-time 8 --retry 0 \
      -H "Authorization: Bearer $secret" --data-urlencode "url=$latency_url" \
      --data-urlencode 'timeout=5000' -- "$api/proxies/$encoded/delay" 2>/dev/null) &&
      delay=$(jq -er '.delay | select(type == "number")' <<< "$response"); then
      sum=$((sum + delay)); successes=$((successes + 1))
    else
      failures=$((failures + 1))
    fi
  done
  ((successes > 0)) || return 1
  jq -cn --arg target "$latency_url" --argjson samples "$successes" \
    --argjson failures "$failures" --argjson average "$((sum / successes))" \
    '{kind:"http-delay", target:$target, samples:$samples, failures:$failures,
      average_ms:$average, unit:"ms"}'
}

traffic_measurement() {
  local response
  response=$(timeout 4 websocat -n1 -H="Authorization: Bearer $secret" \
    "ws://$controller/traffic" 2>/dev/null) || return 1
  jq -ce '{kind:"existing-traffic", upload_bytes_per_second:(.up // .upload),
    download_bytes_per_second:(.down // .download), unit:"bytes/s"} |
    select(.upload_bytes_per_second != null and .download_bytes_per_second != null)' <<< "$response"
}

speed_measurement() {
  local body start end duration_ns duration_ms bytes capped=false curl_status=0
  body=$(mktemp "${TMPDIR:-/tmp}/proxyctl-speed.XXXXXXXX")
  temporary_paths+=("$body")
  start=$(date +%s%N)
  set +e
  curl --fail --silent --show-error --location --connect-timeout 5 --max-time 15 --retry 0 \
    --proxy http://127.0.0.1:7890 --range 0-10485759 -- "$speed_test_url" 2>/dev/null |
    head -c 10485760 > "$body"
  curl_status=${PIPESTATUS[0]}
  set -e
  end=$(date +%s%N)
  bytes=$(wc -c < "$body")
  duration_ns=$((end - start))
  duration_ms=$((duration_ns / 1000000))
  ((bytes == 10485760)) && capped=true
  ((bytes > 0 && duration_ms > 0)) || return 1
  [[ $curl_status == 0 || $curl_status == 23 || $curl_status == 28 ]] || return 1
  jq -cn --arg target "$speed_test_url" --argjson bytes "$bytes" \
    --argjson duration_ms "$duration_ms" --argjson capped "$capped" '
    {kind:"download-goodput", target:$target, bytes:$bytes, duration_ms:$duration_ms,
     mib_per_second:(($bytes / 1048576) / ($duration_ms / 1000)),
     mbit_per_second:(($bytes * 8 / 1000000) / ($duration_ms / 1000)), capped:$capped}'
}

status_command() {
  local json=false measurement=none
  while (($#)); do
    case $1 in
      --json) json=true; shift ;;
      --latency | --traffic | --speed-test)
        [[ $measurement == none ]] || die_usage 'choose only one status measurement'
        measurement=${1#--}; shift
        ;;
      *) die_usage "unknown status option '$1'" ;;
    esac
  done
  [[ $json == false || $color_policy != always ]] || color_policy=never
  configure_colors

  local service_state controller_state=not-queried node='' tun_state=absent
  local cache_count=0 cache_age=null operational_failure=false response measurement_json=null
  service_state=$(systemctl is-active mihomo 2>/dev/null || true)
  [[ -n $service_state ]] || service_state=unknown
  if cache=$(cache_json 2>/dev/null); then
    cache_count=$(jq 'length' <<< "$cache")
    if age=$(cache_age_seconds); then cache_age=$age; fi
  fi
  if [[ $service_state == active ]]; then
    if load_secret && response=$(api_get /proxies/PROXY 2>/dev/null); then
      controller_state=reachable
      node=$(jq -r '.now // empty' <<< "$response")
    else
      controller_state=unreachable
      operational_failure=true
    fi
    if ip -j link show dev mihomo >/dev/null 2>&1; then tun_state=active; fi
  else
    controller_state=not-applicable
  fi

  if [[ $measurement != none ]]; then
    [[ $service_state == active ]] || {
      printf '%s\n' 'Measurement requires an already-active proxy; it was not started automatically.' >&2
      operational_failure=true
    }
    [[ $controller_state == reachable ]] || operational_failure=true
    if [[ $operational_failure == false ]]; then
      case $measurement in
        latency) measurement_json=$(latency_measurement "$node") || operational_failure=true ;;
        traffic) measurement_json=$(traffic_measurement) || operational_failure=true ;;
        speed-test) measurement_json=$(speed_measurement) || operational_failure=true ;;
      esac
      if [[ $operational_failure == true ]]; then
        printf 'The requested %s measurement failed.\n' "$measurement" >&2
        measurement_json=$(jq -cn --arg kind "$measurement" '{kind:$kind, error:"measurement failed"}')
      fi
    else
      measurement_json=$(jq -cn --arg kind "$measurement" \
        '{kind:$kind, error:"proxy state does not permit measurement"}')
    fi
  fi

  if [[ $json == true ]]; then
    jq -cn --arg service "$service_state" --arg controller "$controller_state" \
      --arg node "$node" --arg tun "$tun_state" --argjson cache_count "$cache_count" \
      --argjson cache_age "$cache_age" --argjson measurement "$measurement_json" \
      '{timestamp:(now | todateiso8601), service:$service, controller:$controller,
        mode:"rule", node:(if $node == "" then null else $node end), tun:$tun,
        cache:{usable_nodes:$cache_count, age_seconds:$cache_age}, measurement:$measurement}'
  else
    printf '%sKoru Proxy%s\n' "$c_heading" "$c_reset"
    printf '  Service       %s%s%s\n' "$c_success" "$service_state" "$c_reset"
    printf '  Controller    %s\n' "$controller_state"
    printf '  Mode          rule (all traffic routed to PROXY)\n'
    if [[ -n $node ]]; then printf '  Node          %s\n' "$(safe_display "$node")"; else printf '  Node          unavailable\n'; fi
    printf '  TUN           %s\n' "$tun_state"
    if [[ $cache_age != null ]]; then
      printf '  Node cache    %s usable nodes, refreshed %s ago\n' "$cache_count" "$(format_age "$cache_age")"
    else
      printf '  Node cache    unavailable\n'
    fi
    case $measurement in
      none) printf '  Latency       not measured (use --latency)\n' ;;
      latency)
        if jq -e 'has("error") | not' <<< "$measurement_json" >/dev/null 2>&1; then
          printf '  Latency       %s ms HTTP average (%s samples, %s failures)\n' \
            "$(jq -r .average_ms <<< "$measurement_json")" \
            "$(jq -r .samples <<< "$measurement_json")" "$(jq -r .failures <<< "$measurement_json")"
          printf '  Target        %s\n' "$latency_url"
        else
          printf '  Latency       measurement failed\n'
        fi
        ;;
      traffic)
        if jq -e 'has("error") | not' <<< "$measurement_json" >/dev/null 2>&1; then
          printf '  Traffic       up %s B/s, down %s B/s (existing traffic)\n' \
            "$(jq -r .upload_bytes_per_second <<< "$measurement_json")" \
            "$(jq -r .download_bytes_per_second <<< "$measurement_json")"
        else
          printf '  Traffic       measurement failed\n'
        fi
        ;;
      speed-test)
        if jq -e 'has("error") | not' <<< "$measurement_json" >/dev/null 2>&1; then
          printf '  Goodput       %.2f MiB/s, %.2f Mbit/s (%s bytes, %s ms, capped=%s)\n' \
            "$(jq -r .mib_per_second <<< "$measurement_json")" \
            "$(jq -r .mbit_per_second <<< "$measurement_json")" \
            "$(jq -r .bytes <<< "$measurement_json")" "$(jq -r .duration_ms <<< "$measurement_json")" \
            "$(jq -r .capped <<< "$measurement_json")"
        else
          printf '  Goodput       measurement failed\n'
        fi
        ;;
    esac
  fi
  [[ $operational_failure == false ]]
}

shutdown_command() {
  (($# == 0)) || die_usage 'shutdown takes no arguments'
  if [[ $EUID -ne 0 ]]; then
    exec "$sudo_command" -- "$0" __shutdown
  fi
  systemctl stop mihomo
  printf 'Service: %s\n' "$(systemctl is-active mihomo || true)"
}

args=()
while (($#)); do
  case $1 in
    --color)
      (($# >= 2)) || die_usage '--color requires auto, always or never'
      color_policy=$2
      shift 2
      ;;
    --color=*) color_policy=${1#*=}; shift ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]}"
configure_colors

(($# >= 1)) || die_usage 'a command is required'
command_name=$1
shift
case $command_name in
  start) start_command "$@" ;;
  status) status_command "$@" ;;
  nodes) nodes_command "$@" ;;
  refresh) refresh_command "$@" ;;
  shutdown) shutdown_command "$@" ;;
  help | -h | --help) (($# == 0)) || die_usage 'help takes no arguments'; usage ;;
  stutas) printf "%s\n" "Unknown command 'stutas'. Did you mean 'status'?" >&2; exit 2 ;;
  __enable) enable_node "$@" ;;
  __shutdown)
    [[ $EUID -eq 0 && $# == 0 ]] || die_usage 'invalid internal shutdown request'
    systemctl stop mihomo
    printf 'Service: %s\n' "$(systemctl is-active mihomo || true)"
    ;;
  *) die_usage "unknown command '$command_name'" ;;
esac
