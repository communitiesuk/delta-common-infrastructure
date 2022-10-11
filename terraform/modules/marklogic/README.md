To use this module you need to manually create two AWS secrets:

* `ml-license-${var.environment}` with a value of the form `{"licensee":"foo","license_key":"bar"}`
* `ml-admin-user-${var.environment}` with a value of the form `{"username":"foo","password":"bar"}`

You can manually ssh onto a MarkLogic instance and check the service logs with:
* Port forwarding: `ssh hugeme@$(terraform output -raw bastion_dns_name) -L localhost:9001:instance.ip.here:22`
* SSH (with private key taken from module.marklogic.ml_ssh_private_key): `ssh -i ~/.ssh/privatekey ec2-user@localhost -p 9001`
* On the instance: `journalctl -u MarkLogic`