#!/bin/bash

set -euo pipefail

REBOOT_MARKER=/var/lib/mailhog-patch-reboot-pending
STALE_MARKER_AGE_MINUTES=180
MAILHOG_START_TIMEOUT_SECONDS=300

wait_for_mailhog() {
  echo "Waiting for MailHog to become active"
  SECONDS=0
  until systemctl is-active --quiet mailhog.service; do
    if (( SECONDS > MAILHOG_START_TIMEOUT_SECONDS )); then
      echo "Error: MailHog did not start"
      systemctl status --no-pager mailhog.service || true
      exit 1
    fi
    sleep 10
  done
  echo "MailHog is active; patching complete at $(date --iso-8601=seconds)"
}

# SSM reruns the script after exit 194; ignore stale markers from missed reruns.
if [[ -f "$REBOOT_MARKER" ]] && [[ -z $(find "$REBOOT_MARKER" -mmin "+$STALE_MARKER_AGE_MINUTES") ]]; then
  echo "Post-reboot pass"
  wait_for_mailhog
  rm -f "$REBOOT_MARKER"
  exit 0
fi

echo "Starting Amazon Linux release upgrade at $(date --iso-8601=seconds)"
dnf install -y /usr/bin/needs-restarting
dnf upgrade --releasever=latest -y

reboot_check_status=0
needs-restarting -r || reboot_check_status=$?
if (( reboot_check_status == 0 )); then
  systemctl restart mailhog.service
  wait_for_mailhog
  rm -f "$REBOOT_MARKER"
  exit 0
fi

touch "$REBOOT_MARKER"
echo "Reboot required (needs-restarting exit $reboot_check_status); requesting SSM reboot"
exit 194
