#!/bin/bash
# Install hostname setup script and systemd unit so it runs before MarkLogic.
# Run as root (e.g. from Packer or cloud-init).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

install -m 0755 "$PROJECT_ROOT/scripts/setup-marklogic-hostname.sh" /usr/local/bin/setup-marklogic-hostname.sh
install -m 0644 -D "$PROJECT_ROOT/systemd/setup-marklogic-hostname.service" /etc/systemd/system/setup-marklogic-hostname.service

if [[ ! -f /etc/default/marklogic-hostname ]]; then
  install -m 0644 "$PROJECT_ROOT/config/marklogic-hostname.example" /etc/default/marklogic-hostname
  echo "Created /etc/default/marklogic-hostname — edit MARKLOGIC_HOSTNAME for your hostname."
fi

systemctl daemon-reload
systemctl enable setup-marklogic-hostname.service

echo "Installed. Hostname will be set on next boot before MarkLogic starts."
