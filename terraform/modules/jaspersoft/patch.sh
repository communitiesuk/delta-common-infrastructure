#!/bin/bash

set -euo pipefail

echo "Script starting at $(date --iso-8601=seconds)"

apt-get update
apt-get upgrade -y

echo "Apt updates complete"

if [ -f /var/run/reboot-required ]; then
  echo "/var/run/reboot-required exists, requesting reboot from SSM agent at $(date --iso-8601=seconds)"
  exit 194 # Reboot and re-run the script https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
fi

echo "No reboot required, complete at $(date --iso-8601=seconds)"
exit 0
