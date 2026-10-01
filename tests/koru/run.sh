#!/usr/bin/env bash
set -euo pipefail
repository_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/repo" "$test_root/state"
touch "$test_root/repo/flake.nix"
git -C "$test_root/repo" init -q
mkdir -p "$test_root/repo/home"
touch "$test_root/repo/home/test-app.nix" "$test_root/repo/home/other-app.nix"
cat > "$test_root/repo/home/modules-enables.nix" <<'MODULES'
{
  enable = {
    test-app = false;
    other-app = true;
  };
}
MODULES
export KORU_REPO=$test_root/repo
export KORU_COLOR_HEADING='#123456'
export XDG_STATE_HOME=$test_root/state
export XDG_RUNTIME_DIR=$test_root/state
export TRACE=$test_root/trace
export KORU_SUDO=$test_root/bin/sudo
export KORU_PROXYCTL=$test_root/bin/proxyctl
export PATH="$test_root/bin:$PATH"
cat > "$test_root/bin/mock" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "${0##*/}" >> "$TRACE"
printf ' <%s>' "$@" >> "$TRACE"
printf '\n' >> "$TRACE"
if [[ ${0##*/} == sudo ]]; then
  exec "$@"
fi
if [[ ${0##*/} == nix && ${FAIL_BUILD:-false} == true ]]; then
  printf '%s\n' 'Mock build failed.' >&2
  exit 42
fi
if [[ ${0##*/} == proxyctl ]]; then
  case $1 in
    status)
      printf '%s\n' '{"service":"inactive","controller":"not-applicable","tun":"absent","node":null,"node_latency_ms":null,"cache":{"usable_nodes":0}}'
      [[ ${FAIL_STATUS:-false} != true ]] || exit 1
      ;;
    nodes) printf '%s\n' '[{"name":"Hong Kong","latency_ms":23}]' ;;
  esac
fi
MOCK
chmod +x "$test_root/bin/mock"
for command in sudo nix nix-env nixos-rebuild home-manager nix-collect-garbage proxyctl; do
  ln -s mock "$test_root/bin/$command"
done
cli=$repository_root/scripts/koru.sh
run() { bash "$cli" "$@"; }
assert_trace() { rg -F -- "$1" "$TRACE" >/dev/null; }
reject() {
  local status=0
  : > "$TRACE"
  run "$@" >/dev/null 2>&1 || status=$?
  [[ $status == 2 && ! -s $TRACE ]]
}
reject system build extra
reject home check --host koru
reject proxy status --json
reject proxy start --node anything
reject proxy refresh --restore
reject store gc --dry-run
reject system rollback
reject home rollback --generation abc
reject system rollback --generation 0
reject proxy nodes
reject store unknown
reject home enable
reject home disable --all
reject home modules unexpected
reject profile build extra
reject profile rollback
reject profile rollback --generation 0
reject profile enable rust
run home modules | rg 'disabled  test-app' >/dev/null
run home enable test-app other-app >/dev/null 2>&1
rg 'test-app = true;' "$test_root/repo/home/modules-enables.nix" >/dev/null
run home disable test-app other-app >/dev/null 2>&1
rg 'other-app = false;' "$test_root/repo/home/modules-enables.nix" >/dev/null
run home validate >/dev/null 2>&1

run system build >/dev/null 2>&1
assert_trace 'nixos-rebuild <switch>'
assert_trace '<--no-update-lock-file>'
run home build >/dev/null 2>&1
assert_trace 'home-manager <switch>'
: > "$TRACE"
run system check >/dev/null 2>&1
assert_trace 'nix <build> <--no-link> <--no-update-lock-file>'
assert_trace '#nixosConfigurations.koru.config.system.build.toplevel>'
if rg 'sudo|switch' "$TRACE"; then exit 1; fi
run home check >/dev/null 2>&1
assert_trace '#homeConfigurations.koru.activationPackage>'
status=0
FAIL_BUILD=true run system check >/dev/null 2>&1 || status=$?
[[ $status == 42 ]]
rg -l 'Mock build failed' "$test_root/state/koru" >/dev/null
run proxy status | rg 'inactive' >/dev/null
status=0
FAIL_STATUS=true run proxy status > "$test_root/status" || status=$?
[[ $status == 1 ]]
rg inactive "$test_root/status" >/dev/null
run proxy list | rg 'Hong Kong' >/dev/null
run proxy refresh >/dev/null 2>&1
assert_trace 'proxyctl <--color> <never> <refresh> <--restore>'
run proxy stop >/dev/null 2>&1
assert_trace 'proxyctl <--color> <never> <shutdown>'
run proxy autostart >/dev/null 2>&1
assert_trace 'proxyctl <--color> <never> <autostart>'
run store gc >/dev/null 2>&1
assert_trace 'sudo <nix-collect-garbage>'
if rg -- '<-d>|<--delete-old>' "$TRACE"; then exit 1; fi

# Exercise real profile traversal and exact-generation selection on fixtures.
export TEST_ROOT=$test_root
export SCRIPT_DIR=$repository_root/scripts
bash <<'TEST'
set -euo pipefail
script_dir=$SCRIPT_DIR
source "$script_dir/koru/common.sh"
koru_init
source "$script_dir/koru/system.sh"
source "$script_dir/koru/home.sh"
mkdir -p "$TEST_ROOT/generation/bin" "$TEST_ROOT/profiles"
cat > "$TEST_ROOT/generation/bin/switch-to-configuration" <<'ACTIVATE'
#!/usr/bin/env bash
printf 'activation <%s>' "$0" >> "$TRACE"
printf ' <%s>' "$@" >> "$TRACE"
printf '\n' >> "$TRACE"
ACTIVATE
cp "$TEST_ROOT/generation/bin/switch-to-configuration" "$TEST_ROOT/generation/activate"
chmod +x "$TEST_ROOT/generation/bin/switch-to-configuration" "$TEST_ROOT/generation/activate"
system_profile=$TEST_ROOT/profiles/system
home_profile=$TEST_ROOT/profiles/home-manager
ln -s "$TEST_ROOT/generation" "$system_profile-7-link"
ln -s system-7-link "$system_profile"
ln -s "$TEST_ROOT/generation" "$home_profile-8-link"
ln -s home-manager-8-link "$home_profile"
koru_system list | rg '7 \*' >/dev/null
koru_home list | rg '8 \*' >/dev/null
koru_lock() { :; }
generation=7
koru_system rollback >/dev/null 2>&1
generation=8
koru_home rollback >/dev/null 2>&1
TEST
assert_trace '<--switch-generation> <7>'
assert_trace 'system-7-link/bin/switch-to-configuration> <switch>'
assert_trace 'home-manager-8-link/activate>'
: > "$TRACE"
status=0
run system rollback --generation=999999 >/dev/null 2>&1 || status=$?
[[ $status == 1 && ! -s $TRACE ]]
python3 "$repository_root/tests/koru/render.py"
printf '%s\n' 'Koru CLI tests passed.'
