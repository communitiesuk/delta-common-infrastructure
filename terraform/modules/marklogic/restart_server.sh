#!/bin/bash

set -euo pipefail

echo "Starting restart server script at $(date --iso-8601=seconds)"

printf 'xquery=
        xquery version "1.0-ml";
        xdmp:restart((xdmp:host()), "Restarting MarkLogic Server so that replication ends up the right way around")
' > restart_server.xqy

#restart_server_script=`aws s3 cp --region eu-west-1 s3://test-marklogic-config/restart_server.xqy /restart_server.xqy`
#echo "$restart_server_script"

echo "Restarting Marklogic server"

curl --anyauth --user admin:spoken-chest -X POST -d @./restart_server.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval
