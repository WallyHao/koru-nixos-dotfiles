#!/usr/bin/env bash
# Globals are initialized by common.sh.
# shellcheck disable=SC2154

koru_proxy() {
  local action=$1 data node delay count status=0
  [[ -x $proxy_command ]] || koru_error 'Proxy service tools are not installed.'
  case $action in
    status)
      data=$("$proxy_command" status --json) || status=$?
      jq -e 'type == "object" and has("service")' <<< "$data" >/dev/null || koru_error 'Proxy status query failed.'
      koru_line heading 'Proxy status'
      koru_field Service "$(jq -r '.service' <<< "$data")"
      koru_field Controller "$(jq -r '.controller' <<< "$data")"
      koru_field TUN "$(jq -r '.tun' <<< "$data")"
      koru_field Node "$(jq -r '.node // "none"' <<< "$data")"
      koru_field 'Cached delay' "$(jq -r 'if .node_latency_ms == null then "unknown" else "\(.node_latency_ms) ms" end' <<< "$data")"
      koru_field Nodes "$(jq -r '.cache.usable_nodes' <<< "$data")"
      return "$status"
      ;;
    list)
      data=$("$proxy_command" nodes --json) || koru_error 'No node cache. Run koru proxy refresh.'
      count=$(jq 'length' <<< "$data")
      koru_line heading "Proxy nodes ($count)"
      while IFS=$'\t' read -r delay node; do
        koru_field "$delay ms" "$node"
      done < <(jq -r '.[] | [.latency_ms, (.name | gsub("[\\x00-\\x1F\\x7F]"; "?"))] | @tsv' <<< "$data")
      ;;
    start)
      [[ -t 0 && -t 1 ]] || koru_error 'Interactive terminal required. Use autostart.'
      koru_lock
      koru_run "$proxy_command" --color never start
      ;;
    refresh) koru_lock; koru_line heading 'Proxy refresh'; koru_run "$proxy_command" --color never refresh --restore ;;
    stop) koru_lock; koru_line heading 'Proxy stop'; koru_run "$proxy_command" --color never shutdown ;;
    autostart) koru_lock; koru_line heading 'Proxy autostart'; koru_run "$proxy_command" --color never autostart ;;
  esac
}
