# AWS Access

## AWS console setup

By "AWS console" we mean the website <https://console.aws.amazon.com/>.

1. Have an account in the DLUHC AWS account (alias `mhclg`), login with your IAM username and password <https://mhclg.signin.aws.amazon.com/console>
2. Set up MFA on your account in the DLUHC account (required for assuming the role in the other accounts)
    1. To do this log in to your account in the web console and navigate to IAM
    2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
    3. Scroll down to the 'Multi-factor authentication' section and work through the wizard to add an MFA using your username as the device name
    4. Log out and back in again
3. You can assume a role in one of the two Delta accounts from the AWS console
    1. Log into the AWS console then click your username in the top right
    2. Select "Switch role"
    3. For "Account" input the account id
        * 486283582667 for dev (test and staging)
        * 468442790030 for prod
    4. For "Role" input the role you're able to assume in that account (e.g. developer, assume-infra-support-staging)
    5. Display Name and colour is up to you, fill them in and press "Switch Role"
    6. Switch to Ireland (eu-west-1) in the region dropdown (top bar, second from the right)

## Viewing logs

Logs can be viewed in [CloudWatch](https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1).

The delta server catalina logs are under the `<environment>/delta-website` Log Group.
To search logs, find the Log Group, press "Search log group" then select a time period and put your search query in quotes in the "Filter events" box.

[Link to Delta website catalina logs in production](https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#logsV2:log-groups/log-group/production$252Fdelta-website/log-events)

MarkLogic and other server logs can also available in CloudWatch.

## Access to Active Directory

RDP and terminal sessions can be started from [Fleet Manager](https://eu-west-1.console.aws.amazon.com/systems-manager/managed-instances?region=eu-west-1) in the Systems Manager console.

Find the `ad-management-server-<environment>` instance and go to Node Actions -> Connect with Remote Desktop.
Login with your Windows domain username and password.
From there you can use Active Directory Users and Computers etc. to manage user accounts.

## AWS CLI Setup

We use the AWS CLI for running Terraform commands locally and connecting to instances via AWS Systems Manager Session Manager, including for the MarkLogic admin UI and query console.

For security, we use [aws-vault](https://github.com/99designs/aws-vault) for storing credentials locally.

### Generating an access key

To use the CLI you will need an AWS Access Key and Secret.

1. Log in to your account in the web console and navigate to IAM
2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
3. Scroll down to the 'Access keys' section and select 'Create access key'
4. Skip through the "best practices & alternatives" (select any option and press next) and "description" steps
5. Ensure you save your access key somewhere secure - such as in a password manager (e.g. private folder in Keeper)

### Install

Install the AWS Command Line Interface: <https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>

Install the Session Manager plugin for the AWS CLI: <https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html>

Restart your terminal after installing.

### Configure - with AWS Vault

We use AWS Vault to securely store AWS credentials locally.

If you have infra-support or developer access to any account, please always use AWS Vault or similar.  
If not you can use _Configure - Access key in config file_ below.

1. Install aws-vault as per the [instructions](https://github.com/99designs/aws-vault#installing)
   1. If using WSL, this is probably something along the lines of:

    ```shell
    sudo apt install pass
    gpg --generate-key
    # Remember the secret passphrase!!!
    # take note of the long string outputted under pub.
    pass init <public key string from above>
    # take a look at the most recent version and use that instead of the below
    wget https://github.com/99designs/aws-vault/releases/download/v6.6.2/aws-vault-linux-amd64
    sudo mv aws-vault-linux-amd64 /usr/local/sbin/aws-vault
    chmod +x /usr/local/sbin/aws-vault
    # Add the following to ~/.bashrc:
    # export AWS_VAULT_BACKEND=pass
    # then either source the .bashrc file or just run the line above in the console.
    # NOTE: You will need to unlock pass with your passphrase to use aws-vault,
    # otherwise you will get "gpg: decryption failed: No secret key"
    # Do this with `pass show dluhc`
    ```

2. Open your AWS config file in whatever text editor you like
    * This lives at ~/.aws/config, you can do this from bash by running `nano ~/.aws/config`, this will also create the
      file if it doesn't exist yet
3. Add the following contents to the file, filling in \<your AWS username> and \<role> where needed

   ```text
   [profile dluhc]
   region = eu-west-1
   mfa_serial = arn:aws:iam::448312965134:mfa/<your AWS username>

   [profile delta-dev]
   source_profile = dluhc
   include_profile = dluhc
   role_arn=arn:aws:iam::486283582667:role/<role>

   [profile delta-prod]
   source_profile = dluhc
   include_profile = dluhc
   role_arn=arn:aws:iam::468442790030:role/<role>
   ```

4. From your terminal run `aws-vault add dluhc` and enter your Access Key ID and Secret Access Key when prompted
    * Note, when you enter the secret access key you will not be able to see your input
5. If you run `aws-vault list` you should see something like

   ```text
   Profile                  Credentials              Sessions
   =======                  ===========              ========
   dluhc                    dluhc                    -
   delta-dev                -                        -
   delta-prod               -                        -
   ```

6. To use these credentials you use the command `aws-vault exec <profile>` - you will be prompted to enter an MFA code
   for the DLUHC account, this is used to create a session which will last a short period of time, during which you
   won't need to enter them again
    1. To run a single command run `aws-vault exec <profile> -- <command>` (where profile is one of 'dluhc',
      `delta-dev` and `delta-prod`)
    2. To start an authenticated subshell run `aws-vault exec <profile>`

### Configure - Access key in config file

Alternatively you can include your AWS Access Key and Secret in plain text in the config file,
this isn't recommended, but is quicker to setup and acceptable for the application-support role.

Note the role will be different for the two accounts, e.g. assume-application-support-staging and assume-application-support-production.

```text
[profile dluhc]
region = eu-west-1
aws_access_key_id=<your AWS access key id>
aws_secret_access_key=<your AWS secret access key>

[profile delta-dev]
source_profile = dluhc
role_arn=arn:aws:iam::486283582667:role/<role>
mfa_serial = arn:aws:iam::448312965134:mfa/<your AWS username>
region = eu-west-1

[profile delta-prod]
source_profile = dluhc
role_arn=arn:aws:iam::468442790030:role/<role>
mfa_serial = arn:aws:iam::448312965134:mfa/<your AWS username>
region = eu-west-1
```

You'll then need to include `--profile delta-dev` or `--profile delta-prod` in your `aws` commands, or set the `AWS_PROFILE` environment variable.

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

AWS Systems Manager Session Manager can be used to connect to instances inside the VPC.

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

There is a script provided for this in [manual_scripts/session_manager](./manual_scripts/session_manager/marklogic.sh)

```sh
# Arguments are environment, local port, remote port
aws-vault exec delta-dev -- bash ./manual_scripts/session_manager/marklogic.sh test 9001 8001
```
