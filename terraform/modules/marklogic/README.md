# MarkLogic

## First time setup

To use this module you need to manually create two AWS secrets:

* `ml-license-${var.environment}` with a value of the form `{"licensee":"foo","license_key":"bar"}`
* `ml-admin-user-${var.environment}` with a value of the form `{"username":"foo","password":"bar"}`
  * Add the tag `"delta-marklogic-deploy-read": "${var.environment}"` so that the delta-marklogic-deploy repo can read it

## SSH access

You can manually ssh onto a MarkLogic instance:

1. `terraform output -raw ml_ssh_private_key > ~/.ssh/ml_privatekey`
2. `ssh -J <username>@$(terraform output -raw bastion_dns_name) ec2-user@instance.ip.here -i ~/.ssh/your_normal_key -i ~/.ssh/ml_privatekey`

View the logs:

* `journalctl -u MarkLogic`

Restart server:

* `sudo /sbin/service MarkLogic start`

## Changing EBS volume size

* Recommended: Take Delta and CPM offline, take a snapshot of the current EBS volumes
  * In theory this shouldn't need downtime, but who knows with MarkLogic
* Resize them using Terraform
* Restart the MarkLogic service on each node, this should remount the volume and pick up the new size

### MarkLogic rolling restart via SSM

Change "test" to the relevant environment.

```sh
aws ssm send-command --comment "MarkLogic service rolling restart" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=systemctl restart MarkLogic" \
  --target "Key=tag:marklogic:stack:name,Values=marklogic-stack-test" \
  --timeout-seconds 300 --max-concurrency 1
```
