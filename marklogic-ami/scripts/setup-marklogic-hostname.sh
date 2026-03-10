#!/bin/bash
# Setup hostname and DNS for MarkLogic AMI.
# Registers this instance's private IP to the given domain/hostname and sets
# the system hostname so MARKLOGIC_HOST can match. Intended to run before
# the MarkLogic service starts.
#
# Config: environment variables (e.g. from CloudFormation User Data script).
# Optional: /etc/default/marklogic-hostname if present. No file is required.

set -euo pipefail

LOG_TAG="setup-marklogic-hostname"
log() { echo "[$LOG_TAG] $*" | tee -a /var/log/setup-marklogic-hostname.log; }

# Optional: load from env file if present
if [[ -f /etc/default/marklogic-hostname ]]; then
  set -a
  # shellcheck source=/dev/null
  source /etc/default/marklogic-hostname
  set +a
fi

# Hostname: env (from User Data) overrides file; if still unset, use current hostname (e.g. on reboot)
HOSTNAME="${MARKLOGIC_HOSTNAME:-${HOSTNAME:-}}"
if [[ -z "${HOSTNAME:-}" ]]; then
  HOSTNAME=$(hostname 2>/dev/null || echo "localhost")
  log "No MARKLOGIC_HOSTNAME set; using current hostname: $HOSTNAME"
fi

# Get private IP: prefer EC2 metadata, then primary interface
get_private_ip() {
  local ip
  if ip=$(curl -sS --connect-timeout 2 -f "http://169.254.169.254/latest/meta-data/local-ipv4" 2>/dev/null); then
    echo "$ip"
    return
  fi
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -n "${ip:-}" ]]; then
    echo "$ip"
    return
  fi
  log "ERROR: Could not determine private IP"
  return 1
}

PRIVATE_IP=$(get_private_ip)
log "Private IP: $PRIVATE_IP"

# Ensure /etc/hosts has an entry so hostname resolves to private IP
ensure_hosts_entry() {
  local ip="$1"
  local name="$2"
  local hosts_file="/etc/hosts"
  local line="$ip $name"

  if grep -qE "^[0-9.]+\s+${name}\s*$" "$hosts_file" 2>/dev/null; then
    log "Updating existing /etc/hosts entry for $name to $ip"
    awk -v ip="$ip" -v name="$name" '
      $1 ~ /^[0-9.]+$/ && $2 == name { next }
      { print }
      END { print ip, name }
    ' "$hosts_file" > "${hosts_file}.tmp" && mv "${hosts_file}.tmp" "$hosts_file"
  else
    log "Adding hosts entry: $line"
    echo "$line" >> "$hosts_file"
  fi
}

ensure_hosts_entry "$PRIVATE_IP" "$HOSTNAME"

# Set system hostname
log "Setting hostname to: $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME" || true

# Optional: register in Route53 (private hosted zone). Uses MARKLOGIC_HOSTNAME as the record name if R53_DOMAIN is not set.
if [[ -n "${R53_HOSTED_ZONE_ID:-}" ]]; then
  R53_DOMAIN="${R53_DOMAIN:-$HOSTNAME}"
  if [[ -n "${R53_DOMAIN:-}" ]]; then
    if command -v aws &>/dev/null; then
      log "Upserting Route53 A record: $R53_DOMAIN -> $PRIVATE_IP"
      aws route53 change-resource-record-sets \
        --hosted-zone-id "$R53_HOSTED_ZONE_ID" \
        --change-batch "{
          \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
              \"Name\": \"$R53_DOMAIN\",
              \"Type\": \"A\",
              \"TTL\": 300,
              \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
            }
          }]
        }" 2>&1 | tee -a /var/log/setup-marklogic-hostname.log || log "WARN: Route53 update failed (non-fatal)"
    else
      log "WARN: Route53 requested but aws CLI not found (skipping)"
    fi
  fi
fi

log "Done. Hostname is $(hostname). Use MARKLOGIC_HOST=$(hostname) for MarkLogic."
