#!/usr/bin/env bash
set -euo pipefail

repository_root=${KORU_REPO:-$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
selection_file=$repository_root/home/modules-enables.nix

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

cleanup_paths=()
cleanup() {
  local path
  for path in "${cleanup_paths[@]}"; do
    [[ -e $path ]] && rm -rf -- "$path"
  done
}
trap cleanup EXIT

parse_selection() {
  local file=$1
  gawk '
    function trimmed(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function fail(message) {
      printf "%s:%d: %s\n", FILENAME, NR, message > "/dev/stderr"
      failed = 1
    }
    {
      raw = $0
      line = trimmed(raw)
      if (line == "" || line ~ /^#/) next
      if (state == 0 && line == "{") { state = 1; next }
      if (state == 1 && line == "enable = {") { state = 2; next }
      if (state == 2 && line == "};") { state = 3; next }
      if (state == 3 && line == "}") { state = 4; next }
      if (state == 2 && match(line, /^[-A-Za-z0-9]+[[:space:]]*=[[:space:]]*(true|false);([[:space:]]*#.*)?$/)) {
        name = line
        sub(/[[:space:]]*=.*/, "", name)
        value = line
        sub(/^.*=[[:space:]]*/, "", value)
        sub(/;.*$/, "", value)
        if (seen[name]++) fail("duplicate assignment for " name)
        print name "\t" value
        next
      }
      fail("unsupported or ambiguous switchboard syntax")
    }
    END {
      if (state != 4) fail("incomplete switchboard structure")
      if (failed) exit 1
    }
  ' "$file"
}

module_inventory() {
  find "$repository_root/home" -maxdepth 1 -type f -name '*.nix' -printf '%f\n' |
    sed 's/\.nix$//' |
    grep -Ev '^(default|modules-enables|[.]modules-enables[.].*)$' |
    LC_ALL=C sort
}

validate_inventory() {
  local parsed=$1
  local parsed_names inventory_names
  parsed_names=$(cut -f1 "$parsed" | LC_ALL=C sort)
  inventory_names=$(module_inventory)
  if [[ $parsed_names != "$inventory_names" ]]; then
    printf '%s\n' 'Switchboard and module inventory differ:' >&2
    diff -u <(printf '%s\n' "$inventory_names") <(printf '%s\n' "$parsed_names") >&2 || true
    return 1
  fi
}

make_parsed_file() {
  local source=$1 destination=$2
  parse_selection "$source" > "$destination"
  validate_inventory "$destination"
}

format_candidate() {
  local candidate=$1
  if command -v nixfmt >/dev/null; then
    nixfmt "$candidate" >/dev/null
  else
    nix develop --no-update-lock-file "path:$repository_root" --command nixfmt "$candidate" >/dev/null
  fi
}

evaluate_candidate() {
  local candidate=$1
  local source_copy
  source_copy=$(mktemp -d "${TMPDIR:-/tmp}/koru-home-modules.XXXXXXXX")
  cleanup_paths+=("$source_copy")
  cp -a -- "$repository_root/." "$source_copy/repository"
  rm -f -- "$source_copy/repository/home/$(basename -- "$candidate")"
  cp -- "$candidate" "$source_copy/repository/home/modules-enables.nix"
  nix eval --no-update-lock-file --raw \
    "path:$source_copy/repository#homeConfigurations.koru.activationPackage.drvPath" >/dev/null
}

validate_file() {
  local candidate=$1 parsed
  parsed=$(mktemp "${TMPDIR:-/tmp}/koru-home-modules-parsed.XXXXXXXX")
  cleanup_paths+=("$parsed")
  make_parsed_file "$candidate" "$parsed"
  evaluate_candidate "$candidate"
}

list_modules() {
  local parsed
  parsed=$(mktemp "${TMPDIR:-/tmp}/koru-home-modules-list.XXXXXXXX")
  cleanup_paths+=("$parsed")
  make_parsed_file "$selection_file" "$parsed"
  awk -F '\t' '{ printf "%-24s %s\n", $1, $2 }' "$parsed"
}

edit_modules() {
  local desired=$1
  shift
  local -a names=("$@")
  local lock_file=$repository_root/.git/home-modules.lock
  [[ -d $repository_root/.git ]] || lock_file=$repository_root/.home-modules.lock
  exec 9>"$lock_file"
  flock 9

  local original_hash parsed current candidate candidate_parsed name changes=0
  original_hash=$(sha256sum "$selection_file" | cut -d ' ' -f1)
  parsed=$(mktemp "${TMPDIR:-/tmp}/koru-home-modules-current.XXXXXXXX")
  cleanup_paths+=("$parsed")
  make_parsed_file "$selection_file" "$parsed"

  # Validate every requested name before constructing a candidate.
  for name in "${names[@]}"; do
    [[ $name =~ ^[-A-Za-z0-9]+$ ]] || die "invalid module name '$name'"
    current=$(awk -F '\t' -v wanted="$name" '$1 == wanted { print $2 }' "$parsed")
    [[ -n $current ]] || die "unknown Home Manager module '$name'"
    if [[ $current != "$desired" ]]; then changes=$((changes + 1)); fi
  done
  if ((changes == 0)); then
    for name in "${names[@]}"; do
      if [[ $desired == true ]]; then printf 'Already enabled: %s\n' "$name"
      else printf 'Already disabled: %s\n' "$name"; fi
    done
    return 0
  fi

  candidate=$(mktemp "$repository_root/home/.modules-enables.XXXXXXXX.nix")
  cleanup_paths+=("$candidate")
  gawk -v targets="${names[*]}" -v desired="$desired" '
    BEGIN { count = split(targets, names, " "); for (i = 1; i <= count; i++) wanted[names[i]] = 1 }
    {
      line = $0
      probe = line
      sub(/^[[:space:]]+/, "", probe)
      sub(/[[:space:]]*=.*/, "", probe)
      if (probe in wanted) sub(/=[[:space:]]*(true|false);/, "= " desired ";", line)
      print line
    }
  ' "$selection_file" > "$candidate"

  format_candidate "$candidate"
  candidate_parsed=$(mktemp "${TMPDIR:-/tmp}/koru-home-modules-candidate.XXXXXXXX")
  cleanup_paths+=("$candidate_parsed")
  make_parsed_file "$candidate" "$candidate_parsed"
  evaluate_candidate "$candidate"

  local current_hash
  current_hash=$(sha256sum "$selection_file" | cut -d ' ' -f1)
  [[ $current_hash == "$original_hash" ]] || die 'switchboard changed concurrently; original left untouched'
  chmod --reference="$selection_file" "$candidate"
  mv -- "$candidate" "$selection_file"

  for name in "${names[@]}"; do
    if [[ $desired == true ]]; then printf 'Enabled: %s\n' "$name"
    else printf 'Disabled: %s\n' "$name"; fi
  done
  printf '%s\n' 'No profile was activated. Apply with koru home build.'
}

case ${1:-} in
  list) [[ $# == 1 ]] || die 'list takes no arguments'; list_modules ;;
  validate) [[ $# == 1 ]] || die 'validate takes no arguments'; validate_file "$selection_file"; printf '%s\n' 'Home module selection is valid.' ;;
  enable) [[ $# -ge 2 ]] || die 'usage: home-modules enable NAME...'; shift; edit_modules true "$@" ;;
  disable) [[ $# -ge 2 ]] || die 'usage: home-modules disable NAME...'; shift; edit_modules false "$@" ;;
  *) die 'usage: home-modules list|validate|enable NAME|disable NAME' ;;
esac
