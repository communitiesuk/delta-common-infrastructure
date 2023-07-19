#!/bin/bash

set -euo pipefail

echo "Starting metrics run at $(date --iso-8601=seconds)"
START_TIME=$(date +%s)

TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

echo "Instance id $${INSTANCE_ID}"

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
ML_USER=$(echo "$ML_USER_PASS" | jq -r '.username')
ML_PASS=$(echo "$ML_USER_PASS" | jq -r '.password')

if [ "$#" -eq 1 ] && [ "$1" = "create-log-stream" ]; then
  echo "Creating log stream ${LOG_GROUP_NAME}:$${INSTANCE_ID}"
  aws logs create-log-stream --region ${AWS_REGION} --log-group-name ${LOG_GROUP_NAME} --log-stream-name $${INSTANCE_ID} || echo "Ignoring error, assuming log stream already exists"
  exit 0
fi

response=$(cat <(echo "xquery=") /metrics-cron/metrics-json.xqy | curl -sS --fail --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @- \
                -H "Content-type: application/x-www-form-urlencoded" \
                -H "Accept: */*" \
                http://localhost:8002/v1/eval)

# ML always returns "multipart/mixed" content type, we find the line with the output we want in
json=$(echo "$response" | tr -d '\r' | grep "OUTPUT_JSON:" | cut -c13-)

if [ -z "$json" ]; then
  echo "JSON output not found in response"
  echo "$response"
  exit 1
fi

log_lines=$(echo "$json" | jq -c '.[]')
timing_line=$(echo "$START_TIME" | jq -c '{"metric": "script-duration-seconds", "value": (now - . | floor)}')
log_message=$(echo -e "$timing_line\n$log_lines" | jq -cR '[.,inputs] | map({"timestamp": (now * 1000 | floor), "message": .})')

echo "Putting log event to ${LOG_GROUP_NAME}:$${INSTANCE_ID} $${log_message}"

aws logs put-log-events --region ${AWS_REGION} --log-group-name ${LOG_GROUP_NAME} --log-stream-name $${INSTANCE_ID} --log-events "$log_message"

echo "Done"
