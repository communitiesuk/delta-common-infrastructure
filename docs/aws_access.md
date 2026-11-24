# AWS Access

## AWS setup

By "AWS console" we mean the website <https://console.aws.amazon.com/>.
To access this, see [Working with AWS accounts](https://communitiesuk.github.io/mhclg-way/manuals/working-with-aws-accounts.html)

## Viewing logs

Logs can be viewed in CloudWatch

## Access to Active Directory

RDP and terminal sessions can be started from [Fleet Manager](https://eu-west-1.console.aws.amazon.com/systems-manager/managed-instances?region=eu-west-1) in the Systems Manager console.

Find the `ad-management-server-<environment>` instance and go to Node Actions -> Connect with Remote Desktop.
From there you can use Active Directory Users and Computers etc. to manage user accounts.

If you don't have an account on that environment's Windows domain you can create one:

* Connect using the "Admin" account
  * The test admin password can be located in Secrets Manager under `test-active-directory-admin-password`
  * The staging admin password can be located in Secrets Manager under `staging-active-directory-admin-password`
  * The production admin password can be located in Secrets Manager under `production-active-directory-admin-password`
* Open Active Directory Users and Computers
* Navigate to dluhcdata.local -> dluhcdata -> Users
* Right click -> New -> User
* Fill in your first name and last name, then set the "Full name" and "User logon name" fields to a sensible username, e.g. `softwire-firlas`
* Complete the wizard to create the user
* Find and double click on the new user, go to the Member Of tab and add it to the "AWS Delegated Administrators" group
* You can now log out and log back in with the new user

## AWS CLI Setup

We use the AWS CLI for running Terraform commands locally and connecting to instances via AWS Systems Manager Session Manager, including for the MarkLogic admin UI and query console.

### Troubleshooting

* `An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied`
  * Are you using the right profile? The `dluhc` one is very limited.
* `aws-vault: error: exec: aws-vault sessions should be nested with care, unset AWS_VAULT to force`
  * You're trying to nest sessions (e.g. because you used `dluhc` and then `delta-dev`). Type `exit` to exit the dluhc session.
* `gpg: decryption failed: No secret key` in WSL.
  * `pass` is locked. unlock it by running `pass show dluhc` and entering your passphrase.
* `aws-vault: error: add: The handle is invalid.`
  * Use PowerShell instead of Git Bash for adding profiles

### Session Manager CLI access

AWS Systems Manager Session Manager can be used to connect to instances inside the VPC. Go to the [AWS console](https://eu-west-1.console.aws.amazon.com/systems-manager/session-manager/sessions) and start a session. You can elevate your session to the root user if needed. All session manager activity is logged to CloudWatch. 

Port forwarding can also be used, for example to connect to the MarkLogic admin interface:

If you haven't already first [Install the Session Manager plugin for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).
Restart your terminal after installing.

#### Manually port forward

To port forward find the instance id of the server you want to connect to, either from the [EC2 Console](https://eu-west-1.console.aws.amazon.com/ec2/home?region=eu-west-1#Instances) or using the CLI (change "production" for other environments):

```sh
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=MarkLogic-ASG-1" "Name=tag:environment,Values=production" \
  --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
  --output text
```

Remember to use `aws-vault` or set `--profile`.

Then start a port forwarding session:

```sh
aws ssm start-session --target <instance id here> \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"8001\"],\"localPortNumber\":[\"9001\"]}"
```

and connect to <http://localhost:9001/>.
You can run multiple commands in separate terminals to forward multiple ports.

#### Script for connecting to MarkLogic

There is a bash script provided for this in [manual_scripts/session_manager](./manual_scripts/session_manager/marklogic.sh)

```sh
# Arguments are environment, local port, remote port
# Using aws-vault
aws-vault exec delta-dev -- bash ./manual_scripts/session_manager/marklogic.sh test 9001 8001
# Using profiles
AWS_PROFILE=delta-dev ./manual_scripts/session_manager/marklogic.sh test 9001 8001
```
