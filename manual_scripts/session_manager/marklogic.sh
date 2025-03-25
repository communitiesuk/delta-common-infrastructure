#!/bin/bash

set -e

ENVIRONMENT=${1:-test}
LOCAL_PORT=${2:-9001}
REMOTE_PORT=${3:-8001}

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=MarkLogic-ASG-1" "Name=tag:marklogic:stack:name,Values=marklogic-stack-${ENVIRONMENT}" \
  --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
  --output text)
echo "Connecting to $INSTANCE_ID forwarding $LOCAL_PORT -> $REMOTE_PORT"
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
