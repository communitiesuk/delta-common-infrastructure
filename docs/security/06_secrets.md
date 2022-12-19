# Secrets

## Terraform state

TODO DT-170: Try and ensure state compromise would not directly compromise the environment
  So remove bastion SSH key, AWS access keys.

## Secrets Manager

AWS Secrets Manager is used to manage application secrets.
Some of these are directly managed or have their values accessed by Terraform,
but most must be manually created and only secret metadata is read by Terraform, with the value being read by the relevant application.

## Shared secrets

Policy: All shared production secrets, (e.g. admin passwords from MarkLogic and Active Directory), should be stored in Secrets Manager.
Exceptions only as required for disaster recovery.

Shared secrets for staging and test may be stored in a shared password vault.
