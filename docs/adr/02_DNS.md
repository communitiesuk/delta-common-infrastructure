# DNS

## Current state

This is from exploring existing relevant DNS records.

* communities.gov.uk - owned by DLUHC, uses CloudFlare's Name servers
* delta.communities.gov.uk - delegated to Route53, and aliased to CloudFront
* api.delta.communities.gov.uk - Returns A records, likely aliased to an ALB
* auth.delta.communities.gov.uk - Returns A records, likely aliased to an ALB
* reporting.delta.communities.gov.uk - CNAME to an ALB
* cpm.communities.gov.uk - CNAME to an ALB

Note that the delegation of delta.communities.gov.uk currently has a high TTL that will need to be reduced before the migration.

## Aims

* No domain delegation - decision from DLUHC's Cyber team
* delta.communities.gov.uk, reporting.delta.communities.gov.uk, api.delta.communities.gov.uk and likely a couple of others pointing at our CloudFront distribution(s)
  * And similar for delta.staging.communities.gov.uk etc.
* No regular changes required from DLUHC
  * So automated SSL certificate renewal for said CloudFront distribution
  * As far as possible internal changes to our infrastructure shouldn't require changes from DLUHC
* We can create SSL certificates for our ALBs (without manual changes)
* Be able to test the sites before switching DNS during go live

## Design

We've opted to use separate CloudFront distributions for each application (CPM, Delta, Delta API, Keycloak, Jasper Reports).
Delta is the only application that will benefit to any significant degree, we have used CloudFront for all of them mostly for consistency's sake.

We'll use ACM for certificates, requesting a certificate for each application domain in both the us-east-1 and eu-west-1 region for CloudFront and ALBs respectively.
CloudFront will be configured to forward Host headers, and will accept a certificate that matches the host in this case.
We are doing this to minimise the DNS records DLUHC have to create for each environment, as the current process is manual and has a significant lead time for approval.
This limits us somewhat in terms of using SSL within the environment, we are planning to primarily use HTTP for intra-VPC traffic rather than making our own CA or having split-horizon DNS.

Each application domain will have a CNAME record pointing to the CloudFront distribution.

To aid in testing pre-migration and mitigate the delay in DNS records being created by DLUHC the terraform can be configured to use multiple domains.

Emails will be sent via SES from datacollection.levellingup.gov.uk and relevant DNS records will be requested from DLUHC.

## Other environments

Other environments (currently test and staging) should be consistent with production. The domain `staging.communities.gov.uk` is currently in use, so we plan to use `stage.communities.gov.uk` and `test.communities.gov.uk`.

Setting this up the same as production requires DLUHC to maintain a few extra records, but means the environments will be consistent.
