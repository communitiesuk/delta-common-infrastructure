#!/bin/bash

set -euo pipefail

echo "Starting final forest state script at $(date --iso-8601=seconds)"
echo "Checking if all forests are in the correct state"

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')

aws s3 cp --region eu-west-1 s3://${MARKLOGIC_CONFIG_BUCKET}/final_forest_state.xqy /patching/final_forest_state.xqy

set +e
response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/final_forest_state.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval || echo "output:Failed connecting to Marklogic")

STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)

if [ "ALL_FORESTS_IN_CORRECT_STATE" != "$STATUS" ]; then
  echo "Waiting for forests to be in the correct state"
  SECONDS=0
  until [[ "ALL_FORESTS_IN_CORRECT_STATE" == "$STATUS" ]]; do
    if (( SECONDS > 600 )); then
        echo "Error: giving up waiting for forests to enter correct state"
        exit 1
    fi

    sleep 10
    response=$(curl --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/final_forest_state.xqy \
                   -H "Content-type: application/x-www-form-urlencoded" \
                   -H "Accept: text/plain" \
                   http://localhost:8002/v1/eval || echo "output:Failed connecting to Marklogic")

    STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
    echo "waiting for the following forests: $${STATUS}"
  done
fi

echo "All forests in correct state"
