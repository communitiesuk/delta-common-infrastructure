#!/bin/bash
# Replica forests are those whose name contains "rep1" or "replica". Target status after restart: open.

set -euo pipefail

LOG_TAG="restart-replica-forests"
log() { echo "[$LOG_TAG] $*"; }

# Defaults (override with env or /etc/default/marklogic-manage)
ML_HOST="${ML_HOST:-localhost}"
ML_PORT="${ML_PORT:-8002}"
ML_USER="${ML_USER:-admin}"
ML_PASSWORD="${ML_PASSWORD:-}"
BASE_URL="http://${ML_HOST}:${ML_PORT}/manage/v2"
POLL_INTERVAL="${POLL_INTERVAL:-10}"
SYNC_TIMEOUT="${SYNC_TIMEOUT:-600}"
# Forest name pattern (regex) to identify replica forests (default: rep1 or replica)
REPLICA_NAME_PATTERN="${REPLICA_NAME_PATTERN:-rep1|replica}"

if [[ -f /etc/default/marklogic-manage ]]; then
  set -a
  # shellcheck source=/dev/null
  source /etc/default/marklogic-manage
  set +a
fi

if [[ -z "${ML_PASSWORD:-}" ]]; then
  log "ERROR: ML_PASSWORD must be set (or set in /etc/default/marklogic-manage)"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  log "ERROR: jq is required. Install with: apt-get install jq / yum install jq"
  exit 1
fi

curl_api() {
  curl -sS --connect-timeout 10 --digest -u "${ML_USER}:${ML_PASSWORD}" "$@"
}

# GET list of forests; return JSON (default view)
get_forests_list() {
  curl_api -H "Accept: application/json" "${BASE_URL}/forests?format=json"
}

# GET list of forests with status view (includes forest-state per forest)
get_forests_list_status() {
  curl_api -H "Accept: application/json" "${BASE_URL}/forests?format=json&view=status"
}

# GET forest status by id or name
get_forest_status() {
  local id_or_name="$1"
  curl_api -H "Accept: application/json" "${BASE_URL}/forests/${id_or_name}?view=status&format=json"
}

# POST restart on a forest
restart_forest() {
  local id_or_name="$1"
  curl_api -X POST -d "state=restart" -H "Content-Type: application/x-www-form-urlencoded" "${BASE_URL}/forests/${id_or_name}"
}

# Extract replica forest id/name: forests whose name matches REPLICA_NAME_PATTERN (rep1 or replica by default).
# Response: forest-default-list.list-items.list-item[] with idref, nameref.
get_replica_forest_ids() {
  local json
  json=$(get_forests_list)
  if ! echo "$json" | jq -e . &>/dev/null; then
    log "ERROR: Invalid JSON from forests list. Check host, auth, and Manage API."
    echo "$json" | head -5
    return 1
  fi
  # Filter by name matching REPLICA_NAME_PATTERN; prefer nameref (forest name) for display and API
  echo "$json" | jq -r --arg pat "$REPLICA_NAME_PATTERN" '
    (.["forest-default-list"]["list-items"]["list-item"] | if type == "object" then [.] else . end)[] |
    select((.nameref // .name // "") | test($pat)) | .nameref // .idref // empty
  '
}

# Get state from forest status JSON (status-properties.state.value or legacy forest-state)
forest_state() {
  echo "$1" | jq -r '
    .["forest-status"]["status-properties"]["state"]["value"] //
    .["forest-status"]["forest-state"] //
    .forest_status.forest_state // "unknown"
  '
}

# True if state is open or open replica
is_forest_open() {
  [[ "$1" == "open" || "$1" == "open replica" ]]
}

is_forest_sync() {
  [[ "$1" == "sync replicating" || "$1" == "async replicating" ]]
}

wait_for_forest_sync() {
  local id_or_name="$1"
  local deadline
  deadline=$(($(date +%s) + SYNC_TIMEOUT))
  log "Waiting for forest ${id_or_name} to reach sync/async replicating (timeout ${SYNC_TIMEOUT}s)..."
  while true; do
    local status_json state
    status_json=$(get_forest_status "$id_or_name")
    state=$(forest_state "$status_json")
    log "  State: ${state}"
    if is_forest_sync "$state"; then
      log "Forest ${id_or_name} is now ${state}"
      return 0
    fi
    if [[ $(date +%s) -ge "$deadline" ]]; then
      log "ERROR: Timeout waiting for forest ${id_or_name} to reach sync/async replicating (last state: ${state})"
      return 1
    fi
    sleep "$POLL_INTERVAL"
  done
}

list_only() {
  LOG_TAG="list-replica-forests"
  log "Using Manage API at ${BASE_URL}"
  local json_default ids count=0
  json_default=$(get_forests_list)
  if ! echo "$json_default" | jq -e . &>/dev/null; then
    log "ERROR: Invalid JSON from forests list. Check host, auth, and Manage API."
    echo "$json_default" | head -5
    exit 1
  fi
  # Same replica set as restart: name matches REPLICA_NAME_PATTERN (rep1|replica)
  ids=$(echo "$json_default" | jq -r --arg pat "$REPLICA_NAME_PATTERN" '
    (.["forest-default-list"]["list-items"]["list-item"] | if type == "object" then [.] else . end)[] |
    select((.nameref // .name // "") | test($pat)) | .nameref // .idref // empty
  ')
  if [[ -z "$ids" ]]; then
    log "No replica forests found (name matches ${REPLICA_NAME_PATTERN})."
    exit 0
  fi
  log "Open replica forests (name matches ${REPLICA_NAME_PATTERN}):"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    state=$(get_forest_status "$id" | jq -r '.["forest-status"]["status-properties"]["state"]["value"] // .["forest-status"]["forest-state"] // "unknown"')
    if is_forest_open "$state"; then
      echo "  ${id} (${state})"
      ((count++)) || true
    fi
  done <<< "$ids"
  log "Total open: ${count} replica forest(s)"
  exit 0
}

main() {
  LOG_TAG="restarting-forests"
  log "Using Manage API at ${BASE_URL}"
  replicas=()
  while IFS= read -r id; do
    [[ -n "$id" ]] && replicas+=("$id")
  done < <(get_replica_forest_ids)

  if [[ ${#replicas[@]} -eq 0 ]]; then
    log "No replica forests found. Exiting."
    exit 0
  fi

  log "Found ${#replicas[@]} replica forest(s): ${replicas[*]}"
  failed=0
  for id in "${replicas[@]}"; do
    state=$(get_forest_status "$id" | jq -r '.["forest-status"]["status-properties"]["state"]["value"] // .["forest-status"]["forest-state"] // "unknown"')
    log "Restarting forest: ${id} (current state: ${state})"
    if ! restart_forest "$id"; then
      log "ERROR: Restart request failed for forest ${id}"
      ((failed++)) || true
      continue
    fi
    if ! wait_for_forest_sync "$id"; then
      ((failed++)) || true
    fi
  done

  if [[ $failed -gt 0 ]]; then
    log "Completed with ${failed} failure(s)."
    exit 1
  fi
  log "All replica forests restarted and reached sync/async replicating."
}

usage() {
  echo "Usage: $0 -l|--list          List only open replica forests (name matches rep1 or replica)"
  echo "       $0 -r|--restart      Restart replica forests and move next when each is sync/async replicating"
  echo ""
  echo "Set ML_HOST, ML_USER, ML_PASSWORD (and optionally ML_PORT) in env or /etc/default/marklogic-manage"
}

case "${1:-}" in
  -l|--list)    list_only ;;
  -r|--restart) main "$@" ;;
  -h|--help)     usage ;;
  *)            usage; exit 1 ;;
esac
