#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/proxyctl-tests.XXXXXXXX")
background_test_pid=''
test_cleanup() {
  if [[ -n $background_test_pid ]]; then
    touch "$test_root/fetch-release"
    kill "$background_test_pid" 2>/dev/null || true
    wait "$background_test_pid" 2>/dev/null || true
  fi
  rm -rf -- "$test_root"
}
trap test_cleanup EXIT
mkdir -p "$test_root/bin" "$test_root/config"

cat > "$test_root/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "${MOCK_LOG:?}"
case ${1:-} in
  is-active)
    if [[ ${MOCK_SERVICE_STATE:-inactive} == active ]]; then
      printf '%s\n' active
      exit 0
    fi
    printf '%s\n' "${MOCK_SERVICE_STATE:-inactive}"
    exit 3
    ;;
  is-failed) exit 1 ;;
  *) exit 0 ;;
esac
MOCK

cat > "$test_root/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'curl called\n' >> "${MOCK_LOG:?}"
case "$*" in
  */proxies/PROXY*) printf '%s\n' '{"now":"Node [$x]; 香港","all":["Node [$x]; 香港"]}' ;;
  */version*) printf '%s\n' '{"version":"test"}' ;;
  *) printf '%s\n' '{}' ;;
esac
MOCK

cat > "$test_root/bin/ip" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK

cat > "$test_root/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "${MOCK_LOG:?}"
exit 99
MOCK

chmod 0755 "$test_root/bin/"*

export PATH="$test_root/bin:$PATH"
export MOCK_LOG=$test_root/mock.log
export PROXYCTL_CONFIG_DIR=$test_root/config
export PROXYCTL_SUBSCRIPTION_FILE=$test_root/config/subscription-url
export PROXYCTL_SECRET_FILE=$test_root/config/api-secret
export PROXYCTL_PROVIDER_FILE=$test_root/config/provider.yaml
export PROXYCTL_NODES_FILE=$test_root/config/nodes.json
export PROXYCTL_LEGACY_NODES_FILE=$test_root/config/nodes.tsv
export PROXYCTL_SUDO=$test_root/bin/sudo
PROXYCTL_OWNER=$(id -un)
export PROXYCTL_OWNER
export PROXYCTL_LATENCY_URL=https://example.invalid/latency
export PROXYCTL_SPEED_TEST_URL=https://example.invalid/speed

proxyctl=$repository_root/scripts/proxyctl.sh

help_output=$($proxyctl help)
grep -F 'status [MEASUREMENT]' <<< "$help_output" >/dev/null
if grep -F '__enable' <<< "$help_output" >/dev/null; then
  printf '%s\n' 'hidden commands leaked into help' >&2
  exit 1
fi

set +e
typo_output=$($proxyctl stutas 2>&1)
typo_status=$?
set -e
[[ $typo_status == 2 ]]
grep -F "Did you mean 'status'?" <<< "$typo_output" >/dev/null

export MOCK_SERVICE_STATE=inactive
inactive_json=$($proxyctl status --json)
jq -e '.service == "inactive" and .controller == "not-applicable" and .measurement == null' \
  <<< "$inactive_json" >/dev/null

set +e
inactive_measurement=$($proxyctl status --latency 2>&1)
inactive_measurement_status=$?
set -e
[[ $inactive_measurement_status == 1 ]]
grep -F 'was not started automatically' <<< "$inactive_measurement" >/dev/null

printf '%s' secret > "$PROXYCTL_SECRET_FILE"
# Literal shell metacharacters are part of the upstream node-name fixture.
# shellcheck disable=SC2016
unusual_node='Node [$x]; 香港'
jq -cn --arg name "$unusual_node" '[{name:$name, latency_ms:42}]' > "$PROXYCTL_NODES_FILE"
export MOCK_SERVICE_STATE=active
active_json=$($proxyctl --color never status --json)
jq -e '.service == "active" and .controller == "reachable" and
  .node == "Node [$x]; 香港" and .tun == "absent" and .cache.usable_nodes == 1' \
  <<< "$active_json" >/dev/null

nodes_output=$($proxyctl nodes)
grep -F "$unusual_node" <<< "$nodes_output" >/dev/null

: > "$MOCK_LOG"
set +e
refresh_output=$($proxyctl refresh 2>&1)
refresh_status=$?
set -e
[[ $refresh_status == 1 ]]
grep -F 're-run with --restore' <<< "$refresh_output" >/dev/null
if grep -F 'systemctl stop' "$MOCK_LOG" >/dev/null; then
  printf '%s\n' 'refresh stopped an active service without --restore' >&2
  exit 1
fi

# Real flock, file publication and process cleanup, with all external service
# and network operations confined to fixtures.
cat > "$test_root/bin/mihomo" <<'MOCK'
#!/usr/bin/env bash
if [[ -f $MOCK_PROBE_PID ]] && kill -0 "$(cat "$MOCK_PROBE_PID")" 2>/dev/null; then
  exit 77
fi
printf '%s\n' "$BASHPID" > "${MOCK_PROBE_PID:?}"
trap 'exit 0' TERM INT
while :; do sleep 0.05; done
MOCK
cat > "$test_root/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "${MOCK_LOG:?}"
if [[ $* == *https://example.invalid/subscription* ]]; then
  if [[ ${MOCK_BLOCK_FETCH:-false} == true ]]; then
    touch "$MOCK_FETCH_STARTED"
    while [[ ! -e $MOCK_FETCH_RELEASE ]]; do sleep 0.02; done
  fi
  if [[ ${MOCK_INTERRUPT_FETCH:-false} == true ]]; then
    kill -TERM "$PPID"
    exit 22
  fi
  [[ ${MOCK_FAIL_FETCH:-false} != true ]] || exit 22
  output=''
  while (($#)); do
    if [[ $1 == --output ]]; then output=$2; break; fi
    shift
  done
  cp "$MOCK_PROVIDER" "$output"
elif [[ $* == */group/PROBE/delay* ]]; then
  [[ ${MOCK_FAIL_DELAY:-false} != true ]] || exit 28
  if [[ ${MOCK_FAIL_DELAY_ONCE:-false} == true && ! -e $MOCK_DELAY_ATTEMPT ]]; then
    touch "$MOCK_DELAY_ATTEMPT"
    exit 28
  fi
  cat "$MOCK_DELAYS"
elif [[ $* == */proxies/PROBE* ]]; then
  printf '%s\n' '{"all":["Hong Kong old","Hong Kong new"]}'
elif [[ $* == */proxies/PROXY* ]]; then
  printf '%s\n' '{"now":"Hong Kong old","all":["Hong Kong old"]}'
else
  printf '%s\n' '{"version":"test"}'
fi
MOCK
cat > "$test_root/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf 'sudo %s cache=%s\n' "$*" "$(readlink "$PROXYCTL_CONFIG_DIR/cache/current" || true)" >> "$MOCK_LOG"
if [[ $* == *__enable* && ${MOCK_FAIL_RESTORE:-false} == true ]]; then
  if [[ ${MOCK_FAIL_RESTORE_ONCE:-false} == false || ! -e $MOCK_RESTORE_ATTEMPT ]]; then
    touch "$MOCK_RESTORE_ATTEMPT"
    exit 55
  fi
fi
MOCK
chmod 0755 "$test_root/bin/"*
export MOCK_PROBE_PID=$test_root/probe.pid
export MOCK_PROVIDER=$test_root/provider.yaml
export MOCK_DELAYS=$test_root/delays.json
export MOCK_RESTORE_ATTEMPT=$test_root/restore-attempt
export MOCK_FETCH_STARTED=$test_root/fetch-started
export MOCK_FETCH_RELEASE=$test_root/fetch-release
printf '%s\n' 'https://example.invalid/subscription' > "$PROXYCTL_SUBSCRIPTION_FILE"
printf '%s\n' 'proxies:' '  - {name: Hong Kong old, type: direct}' > "$MOCK_PROVIDER"
cp "$MOCK_PROVIDER" "$PROXYCTL_PROVIDER_FILE"
printf '%s\n' '{"Hong Kong old":42,"Hong Kong new":20}' > "$MOCK_DELAYS"

# Every public mutation is rejected while the lock is held, before any network
# or privileged operation. Read-only node listing still works.
: > "$MOCK_LOG"
(
  flock 9
  for command in refresh start autostart shutdown; do
    status=0
    "$proxyctl" "$command" > "$test_root/locked" 2>&1 || status=$?
    [[ $status == 1 ]]
    grep -F 'Another proxy operation is running.' "$test_root/locked" >/dev/null
  done
  "$proxyctl" nodes >/dev/null
) 9> "$PROXYCTL_CONFIG_DIR/operation.lock"
[[ ! -s $MOCK_LOG ]]

assert_probe_stopped() {
  local pid
  pid=$(cat "$MOCK_PROBE_PID")
  if kill -0 "$pid" 2>/dev/null; then
    printf 'Probe process %s leaked\n' "$pid" >&2
    exit 1
  fi
}

# Successful publication contains both files in one immutable generation.
export MOCK_SERVICE_STATE=inactive
"$proxyctl" refresh > "$test_root/refresh" 2>&1
first_cache=$(readlink "$PROXYCTL_CONFIG_DIR/cache/current")
cmp "$MOCK_PROVIDER" "$first_cache/provider.yaml"
jq -e 'length == 2 and .[0].name == "Hong Kong new"' "$first_cache/nodes.json" >/dev/null
[[ $(stat -c %a "$first_cache") == 700 ]]
[[ $(stat -c %a "$first_cache/provider.yaml") == 600 ]]
assert_probe_stopped

# Download/probe failure and removal of the active node preserve the previous
# complete cache and restore the previous node.
export MOCK_SERVICE_STATE=active
for failure in download probe missing-node; do
  : > "$MOCK_LOG"
  export MOCK_FAIL_FETCH=false MOCK_FAIL_DELAY=false
  printf '%s\n' '{"Hong Kong old":42,"Hong Kong new":20}' > "$MOCK_DELAYS"
  case $failure in
    download) export MOCK_FAIL_FETCH=true ;;
    probe) export MOCK_FAIL_DELAY=true ;;
    missing-node) printf '%s\n' '{"Hong Kong new":20}' > "$MOCK_DELAYS" ;;
  esac
  status=0
  "$proxyctl" refresh --restore > "$test_root/failed" 2>&1 || status=$?
  [[ $status != 0 ]]
  [[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") == "$first_cache" ]]
  grep -F '__enable Hong Kong old' "$MOCK_LOG" >/dev/null
  if [[ $failure != download ]]; then assert_probe_stopped; fi
done
export MOCK_FAIL_FETCH=false MOCK_FAIL_DELAY=false
printf '%s\n' '{"Hong Kong old":42,"Hong Kong new":20}' > "$MOCK_DELAYS"

# Publication failure and a signal immediately after the atomic rename cannot
# expose a partial/deleted generation. Recovery keeps the original pair.
MOCK_REAL_MV=$(command -v mv)
export MOCK_REAL_MV
export MOCK_COMMIT_ATTEMPT=$test_root/commit-attempt
cat > "$test_root/bin/mv" <<'MOCK'
#!/usr/bin/env bash
if [[ ${*: -1} == "$PROXYCTL_CONFIG_DIR/cache/current" ]]; then
  [[ ${MOCK_FAIL_COMMIT:-false} != true ]] || exit 74
  "$MOCK_REAL_MV" "$@"
  if [[ ${MOCK_INTERRUPT_COMMIT:-false} == true && ! -e $MOCK_COMMIT_ATTEMPT ]]; then
    touch "$MOCK_COMMIT_ATTEMPT"
    kill -TERM "$PPID"
  fi
else
  exec "$MOCK_REAL_MV" "$@"
fi
MOCK
chmod 0755 "$test_root/bin/mv"
status=0
MOCK_FAIL_COMMIT=true "$proxyctl" refresh --restore > "$test_root/commit-failed" 2>&1 || status=$?
[[ $status != 0 ]]
[[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") == "$first_cache" ]]
status=0
MOCK_INTERRUPT_COMMIT=true "$proxyctl" refresh --restore > "$test_root/commit-interrupted" 2>&1 || status=$?
[[ $status == 143 ]]
[[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") == "$first_cache" ]]
[[ -s $first_cache/provider.yaml && -s $first_cache/nodes.json ]]
assert_probe_stopped

# Failed service restoration rolls the published cache back, then makes one
# bounded retry against the original generation.
: > "$MOCK_LOG"
export MOCK_FAIL_RESTORE=true MOCK_FAIL_RESTORE_ONCE=true
status=0
"$proxyctl" refresh --restore > "$test_root/failed" 2>&1 || status=$?
[[ $status != 0 ]]
[[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") == "$first_cache" ]]
[[ $(grep -c '__enable Hong Kong old' "$MOCK_LOG") == 2 ]]
last_restore=$(tail -n 1 "$MOCK_LOG")
[[ $last_restore == *"cache=$first_cache" ]]
assert_probe_stopped

# Persistent restoration failures remain visible and never loop indefinitely.
: > "$MOCK_LOG"
export MOCK_FAIL_RESTORE_ONCE=false
status=0
"$proxyctl" refresh --restore > "$test_root/failed" 2>&1 || status=$?
[[ $status != 0 ]]
grep -F 'Could not restore the previous proxy automatically.' "$test_root/failed" >/dev/null
[[ $(grep -c '__enable Hong Kong old' "$MOCK_LOG") == 2 ]]
export MOCK_FAIL_RESTORE=false

# SIGTERM keeps its conventional exit code and runs recovery.
: > "$MOCK_LOG"
status=0
MOCK_INTERRUPT_FETCH=true "$proxyctl" refresh --restore > "$test_root/interrupted" 2>&1 || status=$?
[[ $status == 143 ]]
[[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") == "$first_cache" ]]
grep -F '__enable Hong Kong old' "$MOCK_LOG" >/dev/null

# A live refresh owns the lock until publication and recovery finish.
export MOCK_SERVICE_STATE=inactive
MOCK_BLOCK_FETCH=true "$proxyctl" refresh > "$test_root/concurrent" 2>&1 &
refresh_pid=$!
background_test_pid=$refresh_pid
for _ in $(seq 1 100); do
  [[ ! -e $MOCK_FETCH_STARTED ]] || break
  sleep 0.02
done
[[ -e $MOCK_FETCH_STARTED ]]
status=0
"$proxyctl" shutdown > "$test_root/locked" 2>&1 || status=$?
[[ $status == 1 ]]
"$proxyctl" nodes --json | jq -e 'length == 2' >/dev/null
touch "$MOCK_FETCH_RELEASE"
wait "$refresh_pid"
background_test_pid=
[[ $(readlink "$PROXYCTL_CONFIG_DIR/cache/current") != "$first_cache" ]]
cmp "$MOCK_PROVIDER" "$first_cache/provider.yaml"
assert_probe_stopped

# Autostart retries dispose of the failed attempt before launching a new probe.
mkdir -p "$test_root/autostart"
printf '%s\n' 'https://example.invalid/subscription' > "$test_root/autostart/subscription-url"
PROXYCTL_CONFIG_DIR=$test_root/autostart \
PROXYCTL_PROVIDER_FILE=$test_root/autostart/provider.yaml \
PROXYCTL_NODES_FILE=$test_root/autostart/nodes.json \
PROXYCTL_LEGACY_NODES_FILE=$test_root/autostart/nodes.tsv \
PROXYCTL_SUBSCRIPTION_FILE=$test_root/autostart/subscription-url \
MOCK_FAIL_DELAY_ONCE=true MOCK_DELAY_ATTEMPT=$test_root/delay-attempt \
  "$proxyctl" autostart > "$test_root/autostart.log" 2>&1
[[ -e $test_root/delay-attempt ]]
[[ -L $test_root/autostart/cache/current ]]
assert_probe_stopped

printf '%s\n' 'proxyctl tests passed'
