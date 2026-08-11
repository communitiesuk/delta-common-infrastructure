#!/bin/bash

set -euo pipefail

echo "Starting restart server script at $(date --iso-8601=seconds)"

export AWS_REGION=${AWS_REGION}
export AWS_DEFAULT_REGION=${AWS_REGION}

# This runs shortly after the patch reboot, when IMDS may not be serving instance
# profile credentials yet. The CLI defaults of a 1 second timeout and a single attempt
# then fail as NoCredentials, and set -e aborts before MarkLogic is restarted.
# Poll IMDS directly instead of `aws sts get-caller-identity` — STS may hang behind
# the network firewall even when regional STS HTTPS is allowlisted.
export AWS_METADATA_SERVICE_TIMEOUT=10
export AWS_METADATA_SERVICE_NUM_ATTEMPTS=5

echo "Waiting for instance credentials via IMDS"
for _ in $(seq 1 30); do
  TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
  if [[ -n "$TOKEN" ]]; then
    ROLE=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null || true)
    if [[ -n "$ROLE" ]] && curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" \
      "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE" 2>/dev/null | grep -q AccessKeyId; then
      break
    fi
  fi
  sleep 10
done
TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
ROLE=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE" | grep -q AccessKeyId

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')

printf 'xquery=
        xquery version "1.0-ml";
        xdmp:restart((xdmp:host()), "Restarting MarkLogic Server so that replication ends up the right way around")
' > /patching/restart_server.xqy

echo "Restarting Marklogic server"

curl -sS --anyauth --user "$ML_USER":"$ML_PASS" -X POST -d @/patching/restart_server.xqy \
               -H "Content-type: application/x-www-form-urlencoded" \
               -H "Accept: text/plain" \
               http://localhost:8002/v1/eval
