#!/usr/bin/env bash
# Globals are initialized by common.sh.
# shellcheck disable=SC2154

koru_store() {
  case $1 in
    status)
      local size used available percent store_size gc_result gc_time
      koru_line heading 'Nix storage'
      read -r size used available percent < <(df -h --output=size,used,avail,pcent /nix/store | tail -n 1)
      koru_field 'Disk total' "$size"
      koru_field 'Disk used' "$used ($percent)"
      koru_field 'Disk free' "$available"
      koru_line muted 'Measuring store size...'
      store_size=$(du -sh /nix/store | cut -f 1)
      koru_field 'Store size' "$store_size"
      gc_result=$(systemctl show nix-gc.service --property=Result --value)
      gc_time=$(systemctl show nix-gc.service --property=ExecMainExitTimestamp --value)
      koru_field 'Last GC' "${gc_result:-unknown}"
      koru_field 'GC finished' "${gc_time:-never}"
      koru_field 'GC timer' "$(systemctl is-active nix-gc.timer || true)"
      ;;
    gc)
      koru_lock
      koru_line heading 'Nix garbage collection'
      koru_line muted 'Retained generations are preserved.'
      koru_run "$sudo_command" nix-collect-garbage
      ;;
  esac
}
