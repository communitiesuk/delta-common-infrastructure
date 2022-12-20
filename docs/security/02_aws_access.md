# AWS Access

Two AWS accounts are used, both under the MHCLG AWS Organisation.

* Production 468442790030 – Production environment only
* Development 486283582667 – Test and Staging environments

Access for humans is managed by DLUHC, signing in via the AWS organisation and role switching.

Service users are created directly in the relevant account and are managed by Terraform, with the exception of the Terraform CI/CD user.

TODO DT-39: enable GuardDuty monitoring AWS access

## Permissions/Roles

### Developer

Effectively admin access

TODO DT-163: Set up further roles for

* Monitoring/read only access
* Application developer - access to logs, SSM port forwarding to ML, SSM RDP to AD

## Alarms and monitoring

TODO: Notes for any AWS access alarms we manage

TODO: Notes on monitoring in the AWS organisation to go on Confluence

See <https://digital.dclg.gov.uk/confluence/display/DT/Security+-+DLUHC+responsibilities>
