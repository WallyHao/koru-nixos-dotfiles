#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repository_root"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

host_inventory() {
  nix eval --json --file "$repository_root/hosts/inventory.nix"
}

validate_host() {
  local host=$1
  if ! host_inventory | jq -e --arg host "$host" 'has($host)' >/dev/null; then
    printf 'Unknown host: %s\nAvailable hosts:\n' "$host" >&2
    host_inventory | jq -r 'keys[] | "  " + .' >&2
    exit 2
  fi
}

warn_untracked_sources() {
  local paths
  paths=$(git ls-files --others --exclude-standard -- '*.nix' 'scripts/*' 'completions/*' 2>/dev/null || true)
  if [[ -n $paths ]]; then
    printf '%s\n' 'Warning: Git flakes ignore untracked source paths:' >&2
    while IFS= read -r path; do
      printf '  %s\n' "$path" >&2
    done <<< "$paths"
    printf '%s\n' 'Review them, then use git add --intent-to-add for local evaluation.' >&2
  fi
}

validate_age() {
  [[ $1 =~ ^[1-9][0-9]*d$ ]] || die "invalid age '$1'; expected a positive number followed by d (for example 7d)"
}

confirm_prune() {
  local kind=$1 age=$2 force=$3
  case $force in
    true) return 0 ;;
    false) ;;
    *) die 'force must be true or false' ;;
  esac
  [[ -t 0 ]] || die 'generation pruning needs an interactive confirmation or force=true'
  printf 'Pruning %s generations older than %s reduces rollback coverage.\n' "$kind" "$age" >&2
  printf 'Type prune-%s to continue: ' "$kind" >&2
  local answer
  read -r answer
  [[ $answer == "prune-$kind" ]] || die 'pruning cancelled'
}

system_hosts_list() {
  host_inventory | jq -r 'to_entries[] | "\(.key)\t\(.value.system)"'
}

system_information() {
  local os_name=unknown
  if [[ -r /etc/os-release ]]; then
    os_name=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n 1)
    os_name=${os_name#\"}
    os_name=${os_name%\"}
  fi
  printf 'Host:          %s\n' "$(hostname)"
  printf 'OS:            %s\n' "$os_name"
  printf 'Kernel:        %s\n' "$(uname -sr)"
  printf 'System path:   %s\n' "$(readlink -f /run/current-system 2>/dev/null || printf unavailable)"
}

system_configuration() {
  local action=${1:-} host=${2:-}
  case $action in build | test | switch | boot) ;; *) die 'invalid system action' ;; esac
  [[ -n $host ]] || die 'host is required'
  validate_host "$host"
  warn_untracked_sources
  if [[ $action == build ]]; then
    exec nixos-rebuild build --flake "$repository_root#$host" --no-update-lock-file
  fi
  printf 'Note: nixos-rebuild %s may restart services; test is temporary only.\n' "$action" >&2
  exec sudo nixos-rebuild "$action" --flake "$repository_root#$host" --no-update-lock-file
}

home_configuration() {
  local action=${1:-} host=${2:-}
  case $action in build | switch) ;; *) die 'invalid Home Manager action' ;; esac
  [[ -n $host ]] || die 'host is required'
  validate_host "$host"
  warn_untracked_sources
  exec home-manager "$action" --flake "$repository_root#$host" --no-update-lock-file
}

home_generation_activate() {
  local generation=${1:-}
  [[ $generation =~ ^[0-9]+$ ]] || die 'generation must be a numeric ID from home-generations-list'
  local activation
  activation=$(home-manager generations | awk -v wanted="$generation" '$0 ~ "id " wanted " -> " { print $NF }')
  [[ -n $activation && -x $activation/activate ]] || die "Home Manager generation $generation was not found"
  printf 'Activating Home Manager generation %s (%s)\n' "$generation" "$activation" >&2
  exec "$activation/activate"
}

nix_files() {
  find . -path ./.git -prune -o -name '*.nix' -type f -print0
}

configuration_format() {
  local -a files=()
  mapfile -d '' files < <(nix_files)
  nix fmt --no-update-lock-file -- "${files[@]}"
}

configuration_format_check() {
  local -a files=()
  mapfile -d '' files < <(nix_files)
  nix develop --no-update-lock-file --command nixfmt --check "${files[@]}"
}

configuration_evaluate() {
  local host=${1:-}
  [[ -n $host ]] || die 'host is required'
  validate_host "$host"
  nix eval --no-update-lock-file --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath"
  printf '\n'
  nix eval --no-update-lock-file --raw ".#homeConfigurations.$host.activationPackage.drvPath"
  printf '\n'
}

garbage_collection_preview() {
  printf '%s\n' 'Unreachable store paths (estimate; roots may change before collection):'
  nix-store --gc --print-dead
  printf '\n%s\n' 'System generations retained:'
  nixos-rebuild list-generations
  printf '\n%s\n' 'Standalone Home Manager generations retained:'
  home-manager generations
}

case ${1:-} in
  system-hosts-list) system_hosts_list ;;
  system-information) system_information ;;
  system-generations-list) nixos-rebuild list-generations ;;
  home-generations-list) home-manager generations ;;
  system-configuration) shift; system_configuration "$@" ;;
  home-configuration) shift; home_configuration "$@" ;;
  system-generation-rollback)
    printf '%s\n' 'Rollback changes the active generation but does not restore source files.' >&2
    exec sudo nixos-rebuild switch --rollback
    ;;
  home-generation-activate) home_generation_activate "${2:-}" ;;
  configuration-format) configuration_format ;;
  configuration-format-check) configuration_format_check ;;
  configuration-lint-check)
    exec nix develop --no-update-lock-file --command statix check --config statix.toml .
    ;;
  configuration-dead-code-check)
    exec nix develop --no-update-lock-file --command deadnix --fail .
    ;;
  configuration-evaluate) configuration_evaluate "${2:-}" ;;
  configuration-evaluate-all-home-modules)
    nix eval --no-update-lock-file --raw .#homeConfigurations.all.activationPackage.drvPath
    printf '\n'
    ;;
  configuration-check)
    nix flake check --no-update-lock-file --print-build-logs
    nix flake check --no-update-lock-file --print-build-logs "path:$repository_root/profile"
    configuration_evaluate koru
    nix eval --no-update-lock-file --raw .#homeConfigurations.all.activationPackage.drvPath
    printf '\n'
    ;;
  garbage-collection-preview) garbage_collection_preview ;;
  garbage-collection-run)
    exec nix-collect-garbage
    ;;
  system-generations-prune)
    age=${2:-7d}; force=${3:-false}
    validate_age "$age"; confirm_prune system "$age" "$force"
    exec sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "$age"
    ;;
  home-generations-prune)
    age=${2:-7d}; force=${3:-false}
    validate_age "$age"; confirm_prune home "$age" "$force"
    exec home-manager expire-generations "-$age"
    ;;
  *) die 'unknown maintenance command' ;;
esac
