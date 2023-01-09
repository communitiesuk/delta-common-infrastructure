# MailHog

Email server for the test environment that captures and displays outgoing email.

## Setup

Create a basic auth file for MailHog, see <https://github.com/mailhog/MailHog/blob/master/docs/Auth.md>.
Create a secret to hold the auth file called `mailhog-auth-file-<environment>`, using the default KMS key.

The module creates the server, along with a public ALB and DNS record.
