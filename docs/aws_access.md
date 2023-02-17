# AWS Access

## AWS console setup

By "AWS console" we mean the website <https://console.aws.amazon.com/>.

1. Have an account in the DLUHC AWS account (alias `mhclg`), login with your IAM username and password <https://mhclg.signin.aws.amazon.com/console>
2. Set up MFA on your account in the DLUHC account (required for assuming the role in the other accounts)
    1. To do this log in to your account in the web console and navigate to IAM
    2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
    3. Scroll down to the 'Multi-factor authentication' section and work through the wizard to add an MFA using your username as the device name
    4. Log out and back in again
3. Generate and AWS Access Key in the DLUHC account
    1. To do this log in to your account in the web console and navigate to IAM
    2. On the right hand side use the 'Quick links' section to quickly get to the tab 'My security credentials'
    3. Scroll down to the 'Access keys' section and select 'Create access key'
    4. Ensure you save your access key somewhere secure - such as in a private folder in Keeper
4. You can assume a role in one of the two Delta accounts from the AWS console
    1. Log into the AWS console then click your username in the top right
    2. Select "Switch role"
    3. For "Account" input the account id (486283582667 for dev, 468442790030 for prod)
    4. For "Role" input the role you're able to assume in that account (e.g. developer, assume-infra-support-staging)
    5. Display Name and colour is up to you, fill them in and press "Switch Role"

## AWS CLI

We use the AWS CLI for running Terraform commands locally and connecting to instances via AWS Systems Manager Session Manager.

For security, we use [aws-vault](https://github.com/99designs/aws-vault) for securely storing credentials locally.

### Setting up AWS Vault

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

### Troubleshooting

* `An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied`
  * Are you using the right profile? The `dluhc` one is very limited.
* `aws-vault: error: exec: aws-vault sessions should be nested with care, unset AWS_VAULT to force`
  * You're trying to nest sessions (e.g. because you used `dluhc` and then `delta-dev`). Type `exit` to exit the dluhc session.
* `gpg: decryption failed: No secret key` in WSL.
  * `pass` is locked. unlock it by running `pass show dluhc` and entering your passphrase.
* `aws-vault: error: add: The handle is invalid.`
  * Use PowerShell instead of Git Bash for adding profiles

### Session Manager access

AWS Systems Manager Session Manager can be used to connect to instances inside the VPC.

RDP and terminal sessions can be started from [Fleet Manager](https://eu-west-1.console.aws.amazon.com/systems-manager/managed-instances?region=eu-west-1) in the Systems Manager console.

Port forwarding can also be used, for example to connect to the MarkLogic admin interface:

* [Install the Session Manager plugin for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
* Start a port forwarding session, there is a script provided for this in [manual_scripts/session_manager](./manual_scripts/session_manager/marklogic.sh)

```sh
# Arguments are environment, local port, remote port
aws-vault exec delta-dev -- bash ./manual_scripts/session_manager/marklogic.sh test 9001 8001
```
