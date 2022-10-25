To use this module you need to manually create two AWS secrets:

* `ml-license-${var.environment}` with a value of the form `{"licensee":"foo","license_key":"bar"}`
* `ml-admin-user-${var.environment}` with a value of the form `{"username":"foo","password":"bar"}`

You can manually ssh onto a MarkLogic instance:

1. Port forwarding: `ssh <username>@$(terraform output -raw bastion_dns_name) -L localhost:9001:instance.ip.here:22`
2. SSH (with private key taken from module.marklogic.ml_ssh_private_key): `ssh -i ~/.ssh/privatekey ec2-user@localhost -p 9001`

View the logs:

* `journalctl -u MarkLogic`

Restart server:

* `sudo /sbin/service MarkLogic start`
