#!/usr/bin/env bash
set -euo pipefail

repository_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/proxyctl-tests.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
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

printf '%s\n' 'proxyctl tests passed'
