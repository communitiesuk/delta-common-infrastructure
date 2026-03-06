# MarkLogic AMI – hostname setup

Set the instance **hostname** from its **private IP** and (optionally) register that hostname in DNS, **before** the MarkLogic service starts. Use the same value as `MARKLOGIC_HOST` so MarkLogic binds and advertises the correct host.

## What it does

1. Reads the desired hostname (and optional Route53 settings) from **environment variables** (e.g. when User Data runs the script with `export MARKLOGIC_HOSTNAME=...`). Optional file `/etc/default/marklogic-hostname` is used if present. If neither is set, uses the current hostname (e.g. on reboot).
2. Gets the instance private IP (EC2 metadata or primary interface).
3. Ensures `/etc/hosts` has `private_ip  hostname` so the hostname resolves.
4. Sets the system hostname with `hostnamectl`.
5. Optionally upserts an A record in Route53 (if `R53_HOSTED_ZONE_ID` and `R53_DOMAIN` are set).
6. Runs as a systemd oneshot **before** `MarkLogic.service`, so hostname is ready when MarkLogic starts.

## Quick start

### 1. Install (e.g. in your AMI build or cloud-init)

```bash
sudo ./scripts/install-hostname-setup.sh
```

### 2. Configure hostname

Edit `/etc/default/marklogic-hostname`:

```bash
# Required: hostname to set (use this same value as MARKLOGIC_HOST)
MARKLOGIC_HOSTNAME=ml-node01.example.local

# Optional: register in Route53 private hosted zone
# R53_HOSTED_ZONE_ID=Z0123456789ABCDEF
# R53_DOMAIN=ml-node01.example.local
```

### 3. Set MARKLOGIC_HOST

In your MarkLogic env or systemd override, set:

```bash
export MARKLOGIC_HOST=ml-node01.example.local
# or use $(hostname) after boot
export MARKLOGIC_HOST=$(hostname)
```

After boot, `hostname` and `MARKLOGIC_HOST` will match the same name that resolves to the instance’s private IP.

## CloudFormation: pass all variables via User Data (no file)

The AMI is built with the hostname setup script and systemd unit already installed. At launch time, **pass all variables from CloudFormation parameters through User Data only**. User Data is a **shell script** that exports the parameters and runs the setup script; **no config file is written**.

1. In your template, define parameters (e.g. `MarkLogicHostname`, optional `Route53HostedZoneId`, `Route53Domain`).
2. Set the Launch Template **UserData** to a script that exports and runs:

```yaml
UserData:
  Fn::Base64: !Sub |
    #!/bin/bash
    set -e
    export MARKLOGIC_HOSTNAME="${MarkLogicHostname}"
    export R53_HOSTED_ZONE_ID="${Route53HostedZoneId}"
    export R53_DOMAIN="${Route53Domain}"
    /usr/local/bin/setup-marklogic-hostname.sh
```

3. Pass the parameters when creating the stack. On first boot User Data runs the script with those env vars; hostname and `/etc/hosts` are set. On later reboots the systemd unit runs the script with no env vars, so it uses the existing hostname and just refreshes `/etc/hosts`.

See **`cloudformation/marklogic-launch-template.yaml`** for the full example.

## Cloud-init example (optional env file)

If you prefer an env file instead of passing env vars in the script, you can still create `/etc/default/marklogic-hostname` (e.g. via cloud-config `write_files`) and the script will source it. Or call the script from User Data with exports (no file).

## GitHub Actions: build AMI

A workflow builds the MarkLogic AMI with Packer on GitHub Actions.

**Triggers**
- **Manual:** Actions → Build MarkLogic AMI → Run workflow (optional inputs: region, source_ami_id).
- **Push:** On push to `main` when Packer template or scripts change.

**Setup**
1. **AWS credentials** (choose one):
   - **Secrets:** Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in Settings → Secrets and variables → Actions.
   - **OIDC:** In the workflow, comment out the static credentials and set `role-to-assume: ${{ secrets.AWS_ROLE_ARN }}`; configure the repo as OIDC provider in AWS IAM.
2. **Optional repository variables** (Settings → Secrets and variables → Actions → Variables):  
   `PACKER_VPC_ID`, `PACKER_SUBNET_ID`, `PACKER_SOURCE_AMI_ID` to override defaults.

**Workflow file:** `.github/workflows/build-ami.yml`

## Files

| Path | Purpose |
|------|--------|
| `scripts/setup-marklogic-hostname.sh` | Script that sets hostname and updates /etc/hosts (and optionally Route53). |
| `scripts/install-hostname-setup.sh` | Installs the script and systemd unit. |
| `systemd/setup-marklogic-hostname.service` | Runs after network, before MarkLogic. |
| `config/marklogic-hostname.example` | Example env file for `MARKLOGIC_HOSTNAME`. |
| `cloudformation/marklogic-launch-template.yaml` | Example CloudFormation Launch Template: User Data script that exports parameters and runs the setup script (no file). |
| `cloudformation/userdata-marklogic-hostname.yaml` | User Data script reference for CloudFormation. |
| `.github/workflows/build-ami.yml` | GitHub Actions workflow to build the AMI with Packer. |

## Route53 (optional)

If you set `R53_HOSTED_ZONE_ID` and `R53_DOMAIN` (via User Data exports or in `/etc/default/marklogic-hostname`), the script will use the AWS CLI to UPSERT an A record for that domain to the instance private IP. The instance role (or credentials) needs `route53:ChangeResourceRecordSets` on the hosted zone.

## Ordering

- Service: `After=network-online.target`, `After=cloud-init.service`, `Before=MarkLogic.service`
- So on boot: User Data runs first (exports vars and runs setup script) and/or later the systemd oneshot runs (uses existing hostname if no env) → hostname and /etc/hosts set → MarkLogic starts with correct hostname for `MARKLOGIC_HOST`.
