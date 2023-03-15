# Application traffic

All application traffic arrives through a per-application CloudFront distribution.
AWS WAF is configured for each distribution with appropriate rules for the specific application.

CloudFront forwards traffic to a per-application public ALB which terminates SSL and forwards to the application server(s).
Each CloudFront distribution includes a header with a secret key, the ALB listeners reject traffic without the correct key, preventing connections except through CloudFront.

One exception: the test environment (and only the test environment) has an extra server running MailHog for processing emails which is exposed through an ALB, not CloudFront.

## IP restrictions

In production the Delta API, Keycloak, CPM and Jaspersoft CloudFront distributions are IP restricted to lists that include developers and consumers of the APIs. See [ip_lists.tf](../../terraform/production/ip_lists.tf) for the allowlists.
