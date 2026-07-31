#!/bin/bash

set -euo pipefail

echo "Starting final forest state script at $(date --iso-8601=seconds)"
echo "Checking if all forests are in the correct state"

export AWS_REGION=${AWS_REGION}
export AWS_DEFAULT_REGION=${AWS_REGION}

# This runs shortly after the patch reboot, when IMDS may not be serving instance
# profile credentials yet. The CLI defaults of a 1 second timeout and a single attempt
# then fail as NoCredentials, and set -e aborts before the forests are checked.
export AWS_METADATA_SERVICE_TIMEOUT=10
export AWS_METADATA_SERVICE_NUM_ATTEMPTS=5

echo "Waiting for instance credentials"
for _ in $(seq 1 30); do
  aws sts get-caller-identity > /dev/null 2>&1 && break
  sleep 10
done
aws sts get-caller-identity > /dev/null

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')

aws s3 cp --region ${AWS_REGION} s3://${MARKLOGIC_CONFIG_BUCKET}/final_forest_state.xqy /patching/final_forest_state.xqy
aws s3 cp --region ${AWS_REGION} s3://${MARKLOGIC_CONFIG_BUCKET}/manage-forest-status.sh /patching/manage-forest-status.sh
chmod +x /patching/manage-forest-status.sh

echo "Restarting replica forests to restore expected state"
ML_USER="$ML_USER" ML_PASSWORD="$ML_PASS" bash /patching/manage-forest-status.sh -r

set +e
response=$(curl -sS --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/final_forest_state.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval || echo "output:Failed connecting to Marklogic")

STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)

if [ "ALL_FORESTS_IN_CORRECT_STATE" != "$STATUS" ]; then
  echo "Waiting for forests to be in the correct state"
  SECONDS=0
  until [[ "ALL_FORESTS_IN_CORRECT_STATE" == "$STATUS" ]]; do
    if (( SECONDS > 600 )); then
        echo "Error: giving up waiting for forests to enter correct state at $(date --iso-8601=seconds)"
        exit 1
    fi

    sleep 10
    response=$(curl -sS --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/final_forest_state.xqy \
                   -H "Content-type: application/x-www-form-urlencoded" \
                   -H "Accept: text/plain" \
                   http://localhost:8002/v1/eval || echo "output:Failed connecting to Marklogic")

    STATUS=$(echo "$response" | tr -d '\015' | grep output | cut -d ':' -f2)
    echo "waiting for the following forests: $${STATUS}"
  done
fi

echo "All forests in correct state"
