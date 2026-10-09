#!/bin/bash

set -euo pipefail

# Reboots only when the upgrade needs one. If it does, SSM re-runs this script after
# the reboot requested by exit 194; the marker file survives the reboot and tells the
# second pass to verify the runner came back instead of patching again.
REBOOT_MARKER=/var/lib/gh-runner-patch-reboot-pending
SSM_REBOOT_EXIT_CODE=194
RUNNER_START_TIMEOUT_SECONDS=300
# A marker older than one maintenance window means the post-reboot pass never ran
# (e.g. the upgrade broke the SSM agent). Treat it as stale and patch anyway,
# otherwise a single missed pass would silently stop all future patching.
STALE_MARKER_AGE_MINUTES=180

echo "Starting patch script at $(date --iso-8601=seconds)"

# svc.sh names the unit after the repo and runner, so discover it rather than hard-code it.
runner_unit=$(systemctl list-unit-files --no-legend --no-pager 'actions.runner.*.service' | awk 'NR==1 {print $1}')
if [[ -z "$runner_unit" ]]; then
  echo "Error: no actions.runner.*.service unit found"
  exit 1
fi
echo "Runner unit $runner_unit"

wait_for_runner() {
  echo "Waiting for $runner_unit to become active"
  SECONDS=0
  until systemctl is-active --quiet "$runner_unit"; do
    if (( SECONDS > RUNNER_START_TIMEOUT_SECONDS )); then
      echo "Error: giving up waiting for $runner_unit to start"
      systemctl status --no-pager "$runner_unit" || true
      exit 1
    fi
    sleep 10
  done
  echo "Runner online, patching complete at $(date --iso-8601=seconds)"
}

if [[ -f "$REBOOT_MARKER" ]] && [[ -z $(find "$REBOOT_MARKER" -mmin "+$STALE_MARKER_AGE_MINUTES") ]]; then
  echo "Post-reboot pass"
  rm -f "$REBOOT_MARKER"
  wait_for_runner
  exit 0
fi

# Rebooting mid-job would fail the workflow run. Leave it for the next window.
if pgrep -f Runner.Worker > /dev/null; then
  echo "Runner is executing a job, skipping this maintenance window"
  exit 0
fi

# Installed by path so we do not depend on which package provides it.
echo "Ensuring needs-restarting is available"
dnf install -y /usr/bin/needs-restarting

# Stop the listener so GitHub cannot dispatch a job into the upgrade. The unit stays
# enabled, so it restarts on boot even if the post-reboot pass never runs.
echo "Stopping $runner_unit"
systemctl stop "$runner_unit"

# AL2023 version-locks package repos to the installed system-release, so an in-version
# `yum update` can report "Nothing to do" while newer releases carry kernel/security
# fixes. `--releasever=latest` moves to the newest available 2023.x.y release and
# upgrades every installed package.
echo "Checking for Amazon Linux release updates (informational)"
dnf check-release-update 2>&1 || true
echo "Upgrading Amazon Linux to latest available release"
dnf upgrade --releasever=latest -y

# Exit 0 means no reboot required. Treat any other status as "reboot" so an unexpected
# failure does not leave a stale kernel running.
reboot_check_status=0
needs-restarting -r || reboot_check_status=$?

if (( reboot_check_status == 0 )); then
  echo "No reboot required, restarting the runner"
  systemctl start "$runner_unit"
  wait_for_runner
  exit 0
fi

touch "$REBOOT_MARKER"
echo "Reboot required (needs-restarting exit $reboot_check_status), requesting reboot from SSM agent at $(date --iso-8601=seconds)"
exit $SSM_REBOOT_EXIT_CODE # https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
