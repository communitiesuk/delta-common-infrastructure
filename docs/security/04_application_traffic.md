# Application traffic

All application traffic arrives through a per-application CloudFront distribution.
AWS WAF is configured for each distribution with appropriate rules for the specific application.

CloudFront forwards traffic to a per-application public ALB which terminates SSL and forwards to the application server(s).
Each CloudFront distribution includes a header with a secret key, the ALB listeners reject traffic without the correct key, preventing connections except through CloudFront.

## IP restrictions

TODO DT-150 IP restrictions for API, Keycloak, CPM
