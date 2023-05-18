#!/bin/bash

set -euo pipefail

echo "Starting to check forest state at $(date --iso-8601=seconds)"
set +e
ML_USER=$1
ML_PASS=$2
response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/check_forest_state.xqy \
                -H "Content-type: application/x-www-form-urlencoded" \
                -H "Accept: text/plain" \
                http://localhost:8002/v1/eval || echo "output:Connection failed")

FOREST_STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
echo "Forest status: ${FOREST_STATUS}"

if [ "READY_FOR_RESTART" != "$FOREST_STATUS" ]; then
  echo "Waiting for all forests to be in 'open'/'sync replicating' state"
  SECONDS=0
  until [[ "READY_FOR_RESTART" == "$FOREST_STATUS" ]]; do
      if (( SECONDS > 40 )); then
          echo "Error: giving up waiting for forests to enter 'open'/'sync replicating' state at $(date --iso-8601=seconds)"
          exit 1
      fi

      sleep 10
      response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/check_forest_state.xqy \
                      -H "Content-type: application/x-www-form-urlencoded" \
                      -H "Accept: text/plain" \
                      http://localhost:8002/v1/eval || echo "output:Connection failed")
      FOREST_STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
      echo "Forest status: ${FOREST_STATUS}"
  done
fi
set -e
echo "All forests in 'open'/'sync replicating' state"
