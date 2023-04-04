#!/bin/bash

set -euo pipefail

echo "Starting restart server script at $(date --iso-8601=seconds)"

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')

printf 'xquery=
        xquery version "1.0-ml";
        xdmp:restart((xdmp:host()), "Restarting MarkLogic Server so that replication ends up the right way around")
' > restart_server.xqy

echo "Restarting Marklogic server"

curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @./restart_server.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval