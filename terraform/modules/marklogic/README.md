To use this module you need to manually create two AWS secrets:

* `ml-license-${var.environment}` with a value of the form `{"licensee":"foo","license_key":"bar"}`
* `ml-admin-user-${var.environment}` with a value of the form `{"username":"foo","password":"bar"}`
  * Add the tag `"delta-marklogic-deploy-read": "${var.environment}"` so that the delta-marklogic-deploy repo can read it

You can manually ssh onto a MarkLogic instance:

1. `terraform output -raw ml_ssh_private_key > ~/.ssh/ml_privatekey`
2. `ssh -J <username>@$(terraform output -raw bastion_dns_name) ec2-user@instance.ip.here -i ~/.ssh/your_normal_key -i ~/.ssh/ml_privatekey`

View the logs:

* `journalctl -u MarkLogic`

Restart server:

* `sudo /sbin/service MarkLogic start`
