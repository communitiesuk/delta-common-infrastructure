#!/bin/bash

set -euo pipefail

echo "Script starting at $(date --iso-8601=seconds)"
response=$(curl --anyauth --user admin:admin -X POST -i -d @./check_forest_state.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: multipart/mixed; boundary=BOUNDARY" \
               http://localhost:8002/v1/eval)

STATUS=$(echo "$response" | grep output | cut -d ':' -f2)
echo "Status: ${STATUS}"

if [[ "WAITING_FOR_REPLICATION" == "$STATUS" ]]; then
  echo "Waiting for all forests to be in 'open'/'sync replicating' state"
  SECONDS=0
  until [[ "READY_FOR_RESTART" == "$STATUS" ]]; do
      if (( SECONDS > 600 )); then
          echo "Error: giving up waiting for forests to enter 'open'/'sync replicating' state"
          exit 1
      fi

      sleep 10
      response=$(curl --anyauth --user admin:admin -X POST -i -d @./check_forest_state.xqy \
                     -H "Content-type: application/x-www-form-urlencoded" \
                     -H "Accept: multipart/mixed; boundary=BOUNDARY" \
                     http://localhost:8002/v1/eval)
      STATUS=$(echo "$response" | grep output | cut -d ':' -f2)
      echo "Status: ${STATUS}"
  done
fi

echo "All forests in 'open'/'sync replicating' state"
