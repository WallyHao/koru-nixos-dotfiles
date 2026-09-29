#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/home-modules-tests.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

copy_repository() {
  local name=$1
  mkdir -p "$test_root/$name"
  cp -a -- "$repository_root/." "$test_root/$name/repository"
  printf '%s\n' "$test_root/$name/repository"
}

idempotent_root=$(copy_repository idempotent)
idempotent_output=$("$idempotent_root/scripts/home-modules" enable alacritty)
grep -F 'Already enabled: alacritty' <<< "$idempotent_output" >/dev/null

set +e
unknown_output=$("$idempotent_root/scripts/home-modules" enable unknown-module 2>&1)
unknown_status=$?
set -e
[[ $unknown_status == 2 ]]
grep -F "unknown Home Manager module 'unknown-module'" <<< "$unknown_output" >/dev/null

malformed_root=$(copy_repository malformed)
sed -i 's/    gh = true;/    gh = maybe;/' "$malformed_root/home/module-selection.nix"
set +e
malformed_output=$("$malformed_root/scripts/home-modules" list 2>&1)
malformed_status=$?
set -e
[[ $malformed_status != 0 ]]
grep -F 'unsupported or ambiguous switchboard syntax' <<< "$malformed_output" >/dev/null

dependency_root=$(copy_repository dependency)
before=$(sha256sum "$dependency_root/home/module-selection.nix" | cut -d ' ' -f1)
set +e
dependency_output=$("$dependency_root/scripts/home-modules" disable libreoffice 2>&1)
dependency_status=$?
set -e
after=$(sha256sum "$dependency_root/home/module-selection.nix" | cut -d ' ' -f1)
[[ $dependency_status != 0 && $before == "$after" ]]
grep -F 'zsh requires libreoffice' <<< "$dependency_output" >/dev/null

success_root=$(copy_repository success)
"$success_root/scripts/home-modules" disable gh >/dev/null
grep -F 'gh = false;' "$success_root/home/module-selection.nix" >/dev/null
repeat_output=$("$success_root/scripts/home-modules" disable gh)
grep -F 'Already disabled: gh' <<< "$repeat_output" >/dev/null

lock_root=$(copy_repository lock)
lock_file=$lock_root/.git/home-modules.lock
set +e
(
  flock 9
  timeout 0.2 "$lock_root/scripts/home-modules" disable gh >/dev/null 2>&1
) 9> "$lock_file"
lock_status=$?
set -e
[[ $lock_status == 124 ]]
grep -F 'gh = true;' "$lock_root/home/module-selection.nix" >/dev/null

printf '%s\n' 'home-modules tests passed'
