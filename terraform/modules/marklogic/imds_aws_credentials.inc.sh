# Shared by MarkLogic SSM patch scripts (injected via templatefile).
# After an SSM exit-194 reboot, curl can read AccessKeyId from IMDS while the
# AWS CLI still fails immediately with NoCredentials (exit 253). Export the
# instance-profile keys so later `aws` calls do not use the CLI IMDS client.
# Do not wait on `aws sts get-caller-identity` — STS hangs from these subnets.

export AWS_METADATA_SERVICE_TIMEOUT=10
export AWS_METADATA_SERVICE_NUM_ATTEMPTS=5

load_instance_profile_credentials() {
  local creds attempt
  echo "Waiting for instance credentials via IMDS"
  for attempt in $(seq 1 30); do
    TOKEN=$(curl -sS --max-time 5 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)
    if [[ -n "$TOKEN" ]]; then
      ROLE=$(curl -sS --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null || true)
      if [[ -n "$ROLE" ]]; then
        creds=$(curl -sS --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
          "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE" 2>/dev/null || true)
        if echo "$creds" | grep -q AccessKeyId; then
          eval "$(python3 -c '
import json, sys
c = json.loads(sys.stdin.read())
missing = [k for k in ("AccessKeyId", "SecretAccessKey", "Token") if not c.get(k)]
if missing:
    raise SystemExit("IMDS credentials JSON missing: " + ",".join(missing))
print("export AWS_ACCESS_KEY_ID=" + json.dumps(c["AccessKeyId"]))
print("export AWS_SECRET_ACCESS_KEY=" + json.dumps(c["SecretAccessKey"]))
print("export AWS_SESSION_TOKEN=" + json.dumps(c["Token"]))
' <<< "$creds")"
          echo "Exported instance profile credentials from IMDS (attempt $attempt)"
          return 0
        fi
      fi
    fi
    sleep 10
  done
  echo "Error: instance profile credentials not available from IMDS after 30 attempts" >&2
  return 1
}

aws_retry() {
  local attempt=1
  local max=12
  while true; do
    if command aws "$@"; then
      return 0
    fi
    if (( attempt >= max )); then
      echo "Error: aws $* failed after $attempt attempts" >&2
      return 1
    fi
    echo "aws command failed (attempt $attempt/$max), retrying in 10s"
    attempt=$((attempt + 1))
    sleep 10
  done
}
