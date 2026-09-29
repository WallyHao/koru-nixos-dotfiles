#!/usr/bin/env bash
set -euo pipefail

sysfs_root=${FIELD_NOTES_SYSFS_ROOT:-/sys}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
notes_file=${FIELD_NOTES_FILE:-$state_home/koru/field-notes.jsonl}

read_value() {
  local file=$1 fallback=${2:-}
  if [[ -r $file ]]; then
    tr -d '\n' < "$file"
  else
    printf '%s' "$fallback"
  fi
}

first_system_battery() {
  local supply type scope fallback=
  for supply in "$sysfs_root"/class/power_supply/*; do
    [[ -r $supply/type ]] || continue
    type=$(read_value "$supply/type")
    [[ $type == Battery ]] || continue
    [[ -n $fallback ]] || fallback=$supply
    scope=$(read_value "$supply/scope")
    if [[ $scope == System || ${supply##*/} == BAT* ]]; then
      printf '%s\n' "$supply"
      return 0
    fi
  done
  [[ -n $fallback ]] && printf '%s\n' "$fallback"
}

power_source() {
  local supply type online
  for supply in "$sysfs_root"/class/power_supply/*; do
    [[ -r $supply/type && -r $supply/online ]] || continue
    type=$(read_value "$supply/type")
    case $type in
      Mains | USB | USB_C | USB_PD)
        online=$(read_value "$supply/online" 0)
        [[ $online == 1 ]] && { printf '%s\n' AC; return; }
        ;;
    esac
  done
  printf '%s\n' battery
}

watts_for_battery() {
  local battery=$1 power current voltage
  power=$(read_value "$battery/power_now")
  if [[ $power =~ ^[0-9]+$ ]]; then
    awk -v micro="$power" 'BEGIN { printf "%.3f", micro / 1000000 }'
    return
  fi
  current=$(read_value "$battery/current_now")
  voltage=$(read_value "$battery/voltage_now")
  if [[ $current =~ ^[0-9]+$ && $voltage =~ ^[0-9]+$ ]]; then
    awk -v current="$current" -v voltage="$voltage" \
      'BEGIN { printf "%.3f", (current * voltage) / 1000000000000 }'
    return
  fi
  printf 'null'
}

unique_cpu_value() {
  local name=$1 file value values=
  for file in "$sysfs_root"/devices/system/cpu/cpu*/cpufreq/"$name"; do
    [[ -r $file ]] || continue
    value=$(read_value "$file")
    case " $values " in *" $value "*) ;; *) values+=" $value" ;; esac
  done
  values=${values# }
  [[ -n $values ]] && printf '%s\n' "$values" || printf '%s\n' unknown
}

display_json() {
  local outputs
  if outputs=$(niri msg --json outputs 2>/dev/null); then
    jq -c '
      to_entries | map(select(.value.logical != null)) | .[0] // null |
      if . == null then null else
        (.value.current_mode) as $index | (.value.modes[$index] // null) as $mode |
        {name:.key, brightness_percent:null,
         width:($mode.width // .value.logical.width),
         height:($mode.height // .value.logical.height),
         refresh_hz:(if $mode == null then null else ($mode.refresh_rate / 1000) end)}
      end' <<< "$outputs"
  else
    printf 'null\n'
  fi
}

brightness_percent() {
  local report percent
  report=$(brightnessctl -m 2>/dev/null | head -n 1 || true)
  percent=$(cut -d, -f4 <<< "$report" | tr -d '%')
  [[ $percent =~ ^[0-9]+$ ]] && printf '%s\n' "$percent" || printf 'null\n'
}

network_json() {
  if command -v nmcli >/dev/null 2>&1; then
    nmcli --terse --fields TYPE,STATE,CONNECTION device status 2>/dev/null |
      jq -Rsc 'split("\n") | map(select(length > 0))'
  else
    printf '[]\n'
  fi
}

snapshot_json() {
  local battery source status capacity energy_now energy_full watts display brightness
  local governor preference network load
  battery=$(first_system_battery || true)
  source=$(power_source)
  status=unknown capacity=null energy_now=null energy_full=null watts=null
  if [[ -n $battery ]]; then
    status=$(read_value "$battery/status" unknown)
    capacity=$(read_value "$battery/capacity" null)
    energy_now=$(read_value "$battery/energy_now" null)
    energy_full=$(read_value "$battery/energy_full" null)
    watts=$(watts_for_battery "$battery")
  fi
  [[ $capacity =~ ^[0-9]+$ ]] || capacity=null
  [[ $energy_now =~ ^[0-9]+$ ]] || energy_now=null
  [[ $energy_full =~ ^[0-9]+$ ]] || energy_full=null
  [[ $watts =~ ^[0-9]+([.][0-9]+)?$ ]] || watts=null
  display=$(display_json)
  brightness=$(brightness_percent)
  if [[ $display != null ]]; then
    display=$(jq -c --argjson brightness "$brightness" '.brightness_percent = $brightness' <<< "$display")
  fi
  governor=$(unique_cpu_value scaling_governor)
  preference=$(unique_cpu_value energy_performance_preference)
  network=$(network_json)
  load=$(cut -d ' ' -f1-3 /proc/loadavg)

  jq -cn --arg source "$source" --arg status "$status" --arg governor "$governor" \
    --arg preference "$preference" --arg load "$load" --argjson capacity "$capacity" \
    --argjson energy_now "$energy_now" --argjson energy_full "$energy_full" \
    --argjson watts "$watts" --argjson display "$display" --argjson network "$network" '
    {timestamp:(now | todateiso8601), power_source:$source,
     battery:{status:$status, capacity_percent:$capacity, energy_now_uwh:$energy_now,
       energy_full_uwh:$energy_full, rate_watts:$watts},
     display:$display,
     cpu:{governor:$governor, energy_performance_preference:$preference},
     network:$network, load_average:$load}'
}

print_human() {
  local snapshot=$1
  printf '%s\n' 'Koru Field Notes'
  jq -r '
    "  Time          \(.timestamp)",
    "  Power         \(.power_source) — \(.battery.status)",
    "  Battery       \(.battery.capacity_percent // "unavailable")%",
    "  Rate          \(if .battery.rate_watts == null then "unavailable" else (.battery.rate_watts | tostring) + " W" end)",
    "  Display       \(if .display == null then "unavailable" else "\(.display.width)x\(.display.height) @ \(.display.refresh_hz) Hz, brightness \(.display.brightness_percent)%" end)",
    "  CPU policy    \(.cpu.governor), EPP \(.cpu.energy_performance_preference)",
    "  Load average  \(.load_average)",
    "  Network       \(if (.network | length) == 0 then "unavailable" else (.network | join(", ")) end)"' \
    <<< "$snapshot"
}

usage() {
  cat <<'EOF'
Usage: field-notes [show] [--json]
       field-notes record LABEL

show prints one on-demand power snapshot. record appends a labeled JSON snapshot
to the private local state file for repeatable baseline comparisons. No command
polls, changes a power setting or starts a background service.
EOF
}

case ${1:-show} in
  show)
    shift || true
    snapshot=$(snapshot_json)
    case ${1:-} in
      '') print_human "$snapshot" ;;
      --json) (($# == 1)) || { usage >&2; exit 2; }; printf '%s\n' "$snapshot" ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
  --json)
    (($# == 1)) || { usage >&2; exit 2; }
    snapshot_json
    ;;
  record)
    (($# == 2)) || { usage >&2; exit 2; }
    label=$2
    [[ -n $label && $label != *$'\n'* ]] || { printf '%s\n' 'LABEL must be non-empty and single-line.' >&2; exit 2; }
    snapshot=$(snapshot_json)
    install -d -m 0700 -- "$(dirname -- "$notes_file")"
    (umask 077; jq -c --arg label "$label" '. + {label:$label}' <<< "$snapshot" >> "$notes_file")
    printf 'Recorded field note %q in %s\n' "$label" "$notes_file"
    ;;
  help | -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
