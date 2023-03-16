#!/bin/bash

set -euo pipefail

echo "Script starting at $(date --iso-8601=seconds)"
echo "Restarting Marklogic server"

curl --anyauth --user admin:admin -X POST -i -d @./restart_server.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: multipart/mixed; boundary=BOUNDARY" \
               http://localhost:8002/v1/eval
