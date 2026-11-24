# Patching

Patching of OS-managed packages is automated using cron or AWS Systems Manager Maintenance Windows.

The Active Directory management and certificate authority Windows EC2 instances are patched weekly with `AWS-InstallWindowsUpdates` (not `AWS-RunPatchBaseline`, which hangs after "Posting metrics" and never returns status to SSM). The management instance is patched before the certificate authority instance. Install uses `AllowReboot=False` so the install task does not exit `3010` (which SSM often reports as Failed if reboot-resume races); a following `AWS-RunPowerShellScript` task reboots only when Windows Update / CBS markers show a pending reboot (`exit 3010` for SSM Agent–managed reboot, or exit `0` if none). After reboot, the maintenance window runs a short script on each host to restart Windows Update / USO and trigger a scan so Settings "View update history" is less stale (Settings can still lag under `NoAutoUpdate`; treat build / `Get-HotFix` / SSM logs as source of truth). AWS patches the AWS Managed Microsoft AD domain controllers as part of the managed service.

The test MailHog server is patched at 04:00 UTC on Mondays, Wednesdays and Fridays via an SSM maintenance window. It upgrades to the latest Amazon Linux 2023 release, reboots when needed, and checks that MailHog is running. Failures are sent to the environment's notification email addresses.

The SSH bastions in test, staging, and production upgrade to the latest Amazon Linux 2023 release daily at 03:00 UTC via SSM. The task reboots when needed, checks that SSH responds on the host, sends output to the bastion CloudWatch log group, and alerts the environment's notification email addresses on failure. A reboot interrupts active SSH sessions and tunnels. SSH public key sync runs separately on a five-minute systemd timer.

Other components (vendor application versions, Tomcat etc.) are patched manually on a schedule documented on Confluence as part of the Run Book: <https://mhclgdigital.atlassian.net/wiki/spaces/DT/pages/3375127/Patching>
