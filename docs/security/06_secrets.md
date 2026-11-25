# Secrets

See [05_terraform](./05_terraform.md) for details on the Terraform state, which contains some application secrets.

## Secrets Manager

AWS Secrets Manager is used to manage application secrets.
Some of these are directly managed or have their values accessed by Terraform,
but most must be manually created and only secret metadata is read by Terraform, with the value being read by the relevant application.

## Shared secrets

Policy: All shared production secrets, (e.g. admin passwords from MarkLogic and Active Directory), should be stored in Secrets Manager.
Exceptions only as required for disaster recovery.

Shared secrets for staging and test may be stored in a shared password vault.

## Rotation

Our rotation policy is documented on Confluence: <https://mhclgdigital.atlassian.net/wiki/spaces/DT/pages/3375105/Secret+Rotation>

### Azure DAP export

The `azure_dap_export_rotation_reminder_emails` lists in
[staging](../../terraform/staging/main.tf) and
[production](../../terraform/production/main.tf) include the shared Delta
notifications mailbox. Only production also includes CDS Support. Blank and
`.invalid` entries are ignored; a list with no usable addresses disables the
reminder. Amazon SES sends one message with all configured recipients in the
To field, using the environment's SES sending domain.

The reminder checks at 10:00 UTC daily and attempts to send once per rotation
cycle, 14 calendar days before the latest rotation date reported by AWS. It
doesn't read credentials or change rotation. Manual or earlier rotations may
not get that notice. After enabling staging, verify delivery with a clearly
labelled test send through SES; don't force a key rotation. Seeing an address
in To does not prove delivery. In CloudWatch, look up the SES message ID
(`mail.messageId`) in the environment's SES logs. Check `delivery.recipients`
for mail servers that accepted the message and `bounce.bouncedRecipients` for
reported bounces.

If the Lambda error alarm fires, check the logs and the DynamoDB claim before
following up. A recorded SES message ID means SES accepted the email, not that
the recipient received it. A claim without a message ID leaves the outcome
uncertain; the Lambda won't retry the send automatically. Removing all usable
recipients from Terraform removes the claim table as well as the reminder.
