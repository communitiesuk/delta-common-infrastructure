#!/bin/bash

set -euo pipefail

echo "Script starting at $(date --iso-8601=seconds)"
response=$(curl --anyauth --user admin:admin -X POST -i -d @./check_forest_state.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: multipart/mixed; boundary=BOUNDARY" \
               http://localhost:8002/v1/eval)

MUST_WAIT=$(echo "$response" | grep query-result | cut -d ':' -f2)
echo "Must wait: ${MUST_WAIT}"

if [[ true == "$MUST_WAIT" ]]; then
  echo "Waiting for all forests to be in 'open'/'sync replicating' state"
  SECONDS=0
  until [[ false == "$MUST_WAIT" ]]; do
      if (( SECONDS > 600 )); then
          echo "Error: giving up waiting for forests to enter 'open'/'sync replicating' state"
          exit 1
      fi

      sleep 10
      response=$(curl --anyauth --user admin:admin -X POST -i -d @./check_forest_state.xqy \
                     -H "Content-type: application/x-www-form-urlencoded" \
                     -H "Accept: multipart/mixed; boundary=BOUNDARY" \
                     http://localhost:8002/v1/eval)
      MUST_WAIT=$(echo "$response" | grep query-result | cut -d ':' -f2)
      echo "Waiting: ${MUST_WAIT}"
  done
fi

if [[ false == "$MUST_WAIT" ]]; then
  echo "All forests in 'open'/'sync replicating' state"
  exit 0
fi
