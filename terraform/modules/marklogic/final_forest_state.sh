#!/bin/bash

set -euo pipefail

echo "Starting final forest state script at $(date --iso-8601=seconds)"
echo "Checking if all forests are in the correct state"

#final_forest_state_script=`aws s3 cp --region eu-west-1 s3://test-marklogic-config/final_forest_state.xqy /final_forest_state.xqy`
#echo "$final_forest_state_script"

# shellcheck disable=SC2016
printf 'xquery=
        xquery version "1.0-ml";

        declare namespace h = "http://marklogic.com/xdmp/status/host";
        declare namespace f = "http://marklogic.com/xdmp/status/forest";

        let $all-forests-in-correct-state := (
            for $forest-id in xdmp:forests()
              let $current-forest-status := xdmp:forest-status($forest-id)
              let $current-name := $current-forest-status/(f:forest-name)
              let $current-state := $current-forest-status/(f:state)
              let $rep-forest := (fn:contains($current-name, "rep1") or fn:contains($current-name, "replica"))
              return
                if (($rep-forest and $current-state = "sync replicating") or ($current-state = "open" and fn:not($rep-forest)))
                then ()
                else "false"
        )

        let $failed := ($all-forests-in-correct-state = "false")
        let $output :=
            if ($failed)
            then "ERROR"
            else "ALL_FORESTS_IN_CORRECT_STATE"
        return ("output:" || $output)
' > final_forest_state.xqy

response=$(curl --anyauth --user admin:spoken-chest -X POST -d @./final_forest_state.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval)

STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
echo "Status: ${STATUS}"

if [ "ALL_FORESTS_IN_CORRECT_STATE" != "$STATUS" ]; then
  echo "Error: all forests are not in the correct state"
  exit 1
fi
