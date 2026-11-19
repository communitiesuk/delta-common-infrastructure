# Deploy ephemeral GitHub runners

Repeat per environment, starting with `test`.

1. On the existing GitHub App (`5783568`), approve **Repository Administration: Read and write** and **Actions: Read-only** for `communitiesuk/delta-marklogic-deploy`.
2. In the environment's AWS account (`eu-west-1`), create two **Standard SecureString** parameters using `aws/ssm`. Replace `<env>` with `test`, `staging`, or `production`:
   - `/delta-<env>-ephemeral/app-key-base64`: the base64-encoded GitHub App PEM private key.
   - `/delta-<env>-ephemeral/webhook-secret`: a new random secret for this environment's webhook.
3. Run **Deploy Delta Common Infrastructure** with the chosen **environment** and **stack: `ephemeral-runner`**. The workflow downloads and verifies the Lambda packages. After apply, get the webhook URL and sync Lambda name from the job summary. Confirm the Lambda has synced the runner binary before dispatching jobs.
4. In `delta-marklogic-deploy` → **Settings → Webhooks**, add a repository webhook for the fleet. Use the URL from step 3, `application/json`, SSL verification, the same secret from step 2, and only the **Workflow jobs** event. Leave the app's own webhook unchanged.
5. In `delta-marklogic-deploy`, switch self-hosted jobs to `runs-on: <env>-ephemeral` without `self-hosted`. Keep GitHub environment protections and OIDC roles unchanged; jobs already using staging for `staging1` should use `staging-ephemeral`. Check deploy, test, backup, restore, and import jobs. Use the [GitHub-hosted AMI workflow](../../../.github/workflows/build-marklogic-ami.yml) instead of switching the duplicate Packer job.
6. Confirm a job succeeds, its EC2 instance terminates, and its CloudWatch logs remain available. Then rerun the deployment with **stack: `infrastructure`** to remove that environment's permanent runner and patch window. This also removes the old runner log groups; preserve them first if needed. Remove any remaining offline legacy registration in GitHub.

## Updating the runner module

Dependabot updates the Terraform pin. The PR check automatically verifies all four Lambda packages against upstream's signed build provenance for that release commit. No checksum refresh is needed. Deployment uses the packages verified by its plan job.

On `main`, **Refresh ephemeral runner images** starts at 02:00 UTC on the first of each month. It deploys the `ephemeral-runner` stack to test, staging, then production, subject to each environment's approval rules. Use the manual deploy for urgent updates.
