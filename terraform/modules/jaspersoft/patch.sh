#!/bin/bash

set -euo pipefail

echo "Script starting at $(date --iso-8601=seconds)"

yum update -y

echo "Yum updates complete"

if ! needs-restarting -r; then
  echo "Needs restart, Shutting down Tomcat at $(date --iso-8601=seconds)"
  systemctl stop tomcat
  # We are confident tomcat will stop because we are rebooting, but it does not reliably delete the .pid file
  # So let's just delete it explicitly to avoid the possibility that tomcat fails to restart 
  rm -f /opt/tomcat/latest/temp/tomcat.pid

  echo "Requesting reboot from SSM agent at $(date --iso-8601=seconds)"
  exit 194 # Reboot and re-run the script https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
fi

echo "No reboot required, complete at $(date --iso-8601=seconds)"
exit 0
