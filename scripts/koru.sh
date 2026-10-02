#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/koru/common.sh
source "$script_dir/koru/common.sh"
koru_init

# Utility commands take their own arguments, unlike the maintenance groups.
if [[ ${1:-} == file ]]; then
  shift
  exec python3 "$script_dir/koru/file.py" "$@"
fi
if [[ ${1:-} == click ]]; then
  shift
  exec python3 "$script_dir/koru/click.py" "$@"
fi

group=${1:-}
action=${2:-}
case $group in
  '') koru_help; exit 0 ;;
  -h | --help) (($# == 1)) || koru_usage 'Unexpected arguments.'; koru_help; exit 0 ;;
  system | home | profile | proxy | store) ;;
  *) koru_usage "Unknown group: $group" ;;
esac
case $action in
  '' | -h | --help)
    (($# <= 2)) || koru_usage 'Unexpected arguments.'
    koru_help "$group"; exit 0 ;;
esac
shift 2
case "$group:$action" in
  home:modules | home:enable | home:disable | home:validate) ;;
  profile:build | profile:check | profile:status | profile:list | profile:rollback) ;;
  system:build | system:check | system:list | system:rollback | home:build | home:check | home:list | home:rollback | proxy:status | proxy:list | proxy:refresh | proxy:start | proxy:stop | proxy:autostart | store:gc | store:status) ;;
  *) koru_usage "Unknown command: $group $action" ;;
esac
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  (($# == 1)) || koru_usage 'Unexpected arguments.'
  koru_help "$group" "$action"; exit 0
fi
generation=''
# Command modules consume this array after argument validation.
# shellcheck disable=SC2034
module_names=()
if [[ $action == rollback ]]; then
  case ${1:-} in
    --generation) (($# == 2)) || koru_usage 'Use --generation ID.'; generation=$2 ;;
    --generation=*) (($# == 1)) || koru_usage 'Unexpected arguments.'; generation=${1#*=} ;;
    *) koru_usage 'Use --generation ID.' ;;
  esac
  [[ $generation =~ ^[1-9][0-9]*$ ]] || koru_usage 'Generation must be a positive integer.'
elif [[ $action == enable || $action == disable ]]; then
  (($# > 0)) || koru_usage 'At least one module name is required.'
  for name in "$@"; do
    [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || koru_usage "Invalid module name: $name"
  done
  # shellcheck disable=SC2034
  module_names=("$@")
else
  (($# == 0)) || koru_usage 'This command takes no arguments.'
fi
# shellcheck source=/dev/null
source "$script_dir/koru/$group.sh"
"koru_$group" "$action"
case $action in
  list | status | modules) ;;
  *) koru_line success 'Done.' ;;
esac
