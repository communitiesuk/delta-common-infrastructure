# MailHog

Email server for the test environment that captures and displays outgoing email.

## Setup

Create a basic auth file for MailHog, see <https://github.com/mailhog/MailHog/blob/master/docs/Auth.md>.
Create a secret to hold the auth file called `mailhog-auth-file-<environment>`, using the default KMS key.

The module creates the server, along with a public ALB and DNS record.

## Release

To release an email from Mailhog to send via SES for real:
* Select the email in the Mailhog UI
* Select the "release" button at the top of the screen
* Select the config "ses_test"
* Enter the desired recipient email address, and confirm

You may need to check your spam filter, particularly if you've used a different email address from the original recipient.

## SSH

To SSH to the mailhog server for troubleshooting, get the ssh private key from terraform output and save it to your .ssh folder, for example: `aws-vault exec delta-dev -- terraform output -raw mailhog_ssh_private_key > ~/.ssh/mailhog`

Then ssh via the bastion server, e.g. `ssh -J <your bastion username>@bastion.dluhc-dev.uk -i ~/.ssh/mailhog ec2-user@<private ip of ec2 instance>`
