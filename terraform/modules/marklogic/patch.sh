#!/bin/bash

set -euo pipefail

echo "Starting patch script at $(date --iso-8601=seconds)"

export AWS_REGION=${AWS_REGION}
export AWS_DEFAULT_REGION=${AWS_REGION}

# The SSM agent re-runs this script during boot after the exit 194 reboot, when IMDS
# may not be serving instance profile credentials yet. The CLI defaults of a 1 second
# timeout and a single attempt then fail as NoCredentials, and set -e aborts the run
# before the instance is taken back out of standby.
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

INSTANCE_ID=`curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
AUTOSCALING_GROUP_NAME=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text`
LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`

echo "Instance $${INSTANCE_ID}"
echo "Autoscaling group $${AUTOSCALING_GROUP_NAME}; $${LIFECYCLE_STATE}"

ML_USER_PASS=$(aws secretsmanager get-secret-value --secret-id ml-admin-user-${ENVIRONMENT} --region ${AWS_REGION} --query SecretString --output text)
yum install jq -y # This command has been added to marklogic_cf_template.yml but will need to remain here until the instances are re-created
ML_USER=$(echo $ML_USER_PASS | jq -r '.username')
ML_PASS=$(echo $ML_USER_PASS | jq -r '.password')
mkdir -p /patching # Folder for any patching-related files that are copied down

if [[ "InService" == $LIFECYCLE_STATE ]]; then
  echo "Requesting enter-standby"
  aws autoscaling enter-standby --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALING_GROUP_NAME --should-decrement-desired-capacity
  echo "Waiting for instance to be in standby state"
  SECONDS=0
  until [[ "Standby" == $LIFECYCLE_STATE ]]; do
    if (( SECONDS > 600 )); then
        echo "Error: giving up waiting for instance to enter standby"
        exit 1
    fi

    sleep 10
    LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`
    echo "Current state: $${LIFECYCLE_STATE}"
  done
  
  # AL2023 version-locks package repos to the installed system-release. In-version
  # `yum update --security` often reports "Nothing to do" while newer releases
  # contain kernel/security fixes (e.g. CVE-2026-43499 / ALAS2023-2026-1753).
  # `dnf check-release-update` lists many intermediate versions on stderr and is
  # awkward to parse; `--releasever=latest` upgrades to the newest available.
  echo "Checking for Amazon Linux release updates (informational)"
  dnf check-release-update 2>&1 || true
  echo "Upgrading Amazon Linux to latest available release"
  dnf upgrade --releasever=latest -y
  echo "Updates complete, requesting reboot from SSM agent at $(date --iso-8601=seconds)"
  exit 194 # Reboot and re-run the script https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
fi

if [[ "Standby" == $LIFECYCLE_STATE ]]; then
  echo "Requesting exit-standby"
  aws autoscaling exit-standby --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALING_GROUP_NAME
  echo "Waiting for instance to return to service"
  SECONDS=0
  until [[ "InService" == $LIFECYCLE_STATE ]]; do
    if (( SECONDS > 300 )); then
        echo "Error: giving up waiting for instance to return to service"
        exit 1
    fi

    sleep 10
    LIFECYCLE_STATE=`aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --query 'AutoScalingInstances[0].LifecycleState' --output text`
    echo "Current state: $${LIFECYCLE_STATE}"
  done
  echo "Patching complete at $(date --iso-8601=seconds)"
  exit 0
fi

echo "Unexpected instance state $${LIFECYCLE_STATE}"
exit 1
