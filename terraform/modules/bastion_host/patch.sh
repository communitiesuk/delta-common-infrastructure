#!/bin/bash

set -euo pipefail

REBOOT_MARKER=/var/lib/bastion-patch-reboot-pending
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)

verify_bastion() {
  local start=$SECONDS port
  /usr/sbin/sshd -t
  port=$(/usr/sbin/sshd -T | awk '$1 == "port" && !found++ {print $2}')
  until ssh-keyscan -T 3 -p "$port" 127.0.0.1 >/dev/null 2>&1 \
    && nc -z -w 2 127.0.0.1 2345 >/dev/null 2>&1; do
    if (( SECONDS - start >= 300 )); then
      echo "Error: SSH or the bastion health check listener did not become ready" >&2
      exit 1
    fi
    sleep 5
  done
  echo "Bastion ready: $(cat /etc/system-release), running kernel $(uname -r)"
}

if [[ -f "$REBOOT_MARKER" && $(cat "$REBOOT_MARKER") != "$BOOT_ID" ]]; then
  echo "Verifying bastion after reboot"
  verify_bastion
  rm -f "$REBOOT_MARKER"
  exit 0
fi

if [[ ! -f "$REBOOT_MARKER" ]]; then
  timeout 300 cloud-init status --wait
  dnf install -y /usr/bin/needs-restarting
  dnf upgrade --releasever=latest -y
  /usr/sbin/sshd -t

  status=0
  needs-restarting -r || status=$?
  case "$status" in
    0)
      systemctl restart sshd
      verify_bastion
      exit 0
      ;;
    1) printf '%s\n' "$BOOT_ID" > "$REBOOT_MARKER" ;;
    *) echo "Error: needs-restarting exited $status" >&2; exit "$status" ;;
  esac
fi

echo "Reboot required; requesting reboot through SSM Agent"
exit 194
