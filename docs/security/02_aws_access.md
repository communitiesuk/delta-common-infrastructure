# AWS Access

Two AWS accounts are used, both under the MHCLG AWS Organisation.

* Production 468442790030 – Production environment only
* Development 486283582667 – Test and Staging environments

Access for humans is managed by DLUHC, signing in via an AWS organisation account and role switching.
Since we have no console users we do not set an IAM password policy in our accounts.

Service users are created directly in the relevant account and are managed by Terraform, with the exception of the Terraform CI/CD user.

We have enabled AWS GuardDuty, which can detect suspicious account activity, including unauthorised creation of new IAM users or access keys.

## Permissions/Roles

These are the roles used by humans to access the account.

Managed by DLUHC:

* `developer` - managed by DLUHC, effectively admin access
  * We plan to add an alarm on use of this role and phase it out for day-to-day use, see <https://digital.dclg.gov.uk/confluence/display/DT/Security+-+DLUHC+responsibilities>
* `auditor` and `security-auditor` - read only access

Managed in this repository, environment specific, see [roles.tf](../../terraform/modules/iam_roles/roles.tf)

* `cloudwatch-monitor` - CloudWatch access
* `application-support` - View logs and use SSM to connect to MarkLogic and Active Directory
* `infra-support` - Same as above, plus ReadOnlyAccess, Terraform state read, access to AWS support tickets, and permissions to perform some common actions, like scaling up/down servers

## Alarms and monitoring

Documented as part of the Run Book on Confluence, see <https://digital.dclg.gov.uk/confluence/display/DT/Run+Book>.
