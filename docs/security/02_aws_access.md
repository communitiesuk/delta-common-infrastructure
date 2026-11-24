# AWS Access

Two AWS accounts are used, both under the MHCLG AWS Organisation.

* Production 468442790030 – Production environment only
* Development 486283582667 – Test and Staging environments

Access for humans is managed by DLUHC, signing in via an AWS organisation account and role switching.
Since we have no console users we do not set an IAM password policy in our accounts.

Service users are created directly in the relevant account and are managed by Terraform, with the exception of the Terraform CI/CD user.

We have enabled AWS GuardDuty, which can detect suspicious account activity, including unauthorised creation of new IAM users or access keys.

## Permissions/Roles

You should have both a read-only role and a `developer` role in each AWS account: production and non-production (test and staging).

Managed by DLUHC:

* `developer` - managed by DLUHC, effectively admin access
  * We plan to add an alarm on use of this role and phase it out for day-to-day use, see <https://mhclgdigital.atlassian.net/wiki/spaces/DT/pages/3375167/Security+-+DLUHC+responsibilities>
* `auditor` and `security-auditor` - read only access

## Alarms and monitoring

Documented as part of the Run Book on Confluence, see <https://mhclgdigital.atlassian.net/wiki/spaces/DT/pages/3375129/Run+Book>.
