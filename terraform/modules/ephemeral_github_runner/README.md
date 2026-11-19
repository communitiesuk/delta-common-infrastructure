# Deploy ephemeral GitHub runners

Repeat per environment, starting with `test`. Before deploying, merge the HTTPS checkout migration in `delta-marklogic-deploy` and configure its `RUNNER_APP_PRIVATE_KEY` secret. The new runners do not allow outbound SSH, and applying `infrastructure` removes the shared runner subnet's SSH firewall exception.

1. On the existing GitHub App (`5783568`), approve **Repository Administration: Read and write** and **Actions: Read-only** for `communitiesuk/delta-marklogic-deploy`.
2. In the **AWS Management Console**, switch to **Europe (Ireland) (`eu-west-1`)** and the account for your environment: `486283582667` for test and staging, or `468442790030` for production. Open **Systems Manager → Parameter Store → Create parameter**. Create each parameter separately with **Tier: Standard**, **Type: SecureString**, and **KMS key: `alias/aws/ssm`**. Replace `<env>` with `test`, `staging`, or `production`:
   - `/delta-<env>-ephemeral/app-key-base64`: the base64-encoded GitHub App PEM private key.
   - `/delta-<env>-ephemeral/webhook-secret`: a new random secret for this environment's webhook. On macOS, run `openssl rand -hex 32 | tr -d '\n' | pbcopy` to copy a fresh secret to your clipboard without printing it. Run it separately for each environment and use the value as-is.
   - Enter the secrets in the console, not in this README or Terraform. Keep the webhook secret available for step 4.
3. Run **Deploy Delta Common Infrastructure** with the chosen **environment** and **stack: `ephemeral-runner`**. The workflow downloads and verifies the Lambda packages. After apply, get the webhook URL and sync Lambda name from the job summary. Confirm the Lambda has synced the runner binary before dispatching jobs.
4. In `delta-marklogic-deploy` → **Settings → Webhooks**, add a repository webhook for the fleet. Use the URL from step 3, `application/json`, SSL verification, the same secret from step 2, and only the **Workflow jobs** event. Leave the app's own webhook unchanged.
5. In `delta-marklogic-deploy`, switch self-hosted jobs to `runs-on: <env>-ephemeral` without `self-hosted`. Keep GitHub environment protections and OIDC roles unchanged; jobs already using staging for `staging1` should use `staging-ephemeral`. Check deploy, test, backup, restore, and import jobs. Use the [GitHub-hosted AMI workflow](../../../.github/workflows/build-marklogic-ami.yml) instead of switching the duplicate Packer job.
6. Confirm a job succeeds, its EC2 instance terminates, and its CloudWatch logs remain available. Then rerun the deployment with **stack: `infrastructure`** to remove that environment's permanent runner and patch window. This also removes the old runner log groups; preserve them first if needed. Remove any remaining offline legacy registration in GitHub.

## Updating the runner module

Dependabot updates the Terraform pin. The PR check automatically verifies all four Lambda packages against upstream's signed build provenance for that release commit. No checksum refresh is needed. Deployment uses the packages verified by its plan job.

On `main`, **Refresh ephemeral runner images** starts at 02:00 UTC on the first of each month. It deploys the `ephemeral-runner` stack to test, staging, then production, subject to each environment's approval rules. Use the manual deploy for urgent updates.

## Runner access log bucket: Wiz exceptions

The following exception requests apply only to `runner_access_logs`, the private S3 server access log destination:

- **Customer-managed KMS key:** Keep SSE-S3 encryption. [AWS requires S3-managed keys on this log destination](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html#grant-log-delivery-permissions-general).
- **Replication:** Keep one copy unless audit or recovery policy requires a replica. The bucket is versioned, and noncurrent versions expire after 14 days.
