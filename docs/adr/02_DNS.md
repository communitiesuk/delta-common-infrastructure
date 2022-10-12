# DNS

## Current state

This is from exploring existing relevant DNS records.

* communities.gov.uk - owned by DLUHC, uses CloudFlare's Name servers
* delta.communities.gov.uk - delegated to Route53, and aliased to CloudFront
* api.delta.communities.gov.uk - Returns A records, likely aliased to an ALB
* auth.delta.communities.gov.uk - Returns A records, likely aliased to an ALB
* reporting.communities.gov.uk - CNAME to an ALB
* cpm.communities.gov.uk - CNAME to an ALB

Note that the delegation of delta.communities.gov.uk currently has a high TTL that will need to be reduced before the migration.

## Aims

* delta.communities.gov.uk, reporting.communities.gov.uk, api.delta.communities.gov.uk and likely a couple of others pointing at our CloudFront distribution(s)
  * And similar for delta.staging.communities.gov.uk etc.
* No regular changes required from DLUHC
  * So automated SSL certificate renewal for said CloudFront distribution
  * Internal changes to our infrastructure shouldn't require changes from DLUHC
* DLUHC maintain control of the main communities.gov.uk domain, so no delegating it or wildcard subdomains
* We can create SSL certificates for our ALBs (without manual changes)
* Be able to test the sites before switching DNS during go live

## Proposed records from DLUHC

* `internal.communities.gov.uk` delegated to Route53 in this account
* ACM validation records for a wildcard certificate on `*.communities.gov.uk` and `*.delta.communities.gov.uk`
* `delta.communities.gov.uk` CNAME to `delta.internal.communities.gov.uk`
  * Similar for reporting etc.

## Explanation

We avoid delegating the `delta.communities.gov.uk` subdomain. This returns more control to DLUHC and simplifies the switch over, both in terms of reasoning about TTLs and meaning we can have SSL certificates in place with no need to change validation method after the switch over.

We can create an ACM certificate for `*.communities.gov.uk`, `api.delta.communities.gov.uk` and `*.internal.communities.gov.uk`, which we will attach to the CloudFront distribution.
This should never need to change, even if new domains are added (e.g. for KeyCloak or EClaims), so the validation record can stay static.

CNAMEing `delta.communities.gov.uk` to a domain we control rather than directly to CloudFront means we can make changes internally, e.g. splitting out a separate CloudFront distribution for delta, without requiring DNS changes from DLUHC, as well as giving us a convenient domain to test on before go-live. Having the internal domain means we can make SSL certificates for ALBs and other resources easily.

We may find that we want separate CloudFront distributions, or to point some domains directly at load balancers, in which case we can request new validation records for smaller scope certificates, using the wildcard certificate in the meantime.

Longer term we may want to move `api.delta.communities.gov.uk` to a non-nested domain like `delta-api.communities.gov.uk`, and the same for auth, they run independently from the main delta website anyway, and this would simplify certificate management.

Note that `infra.communities.gov.uk` is already delegated, "internal" was our second choice.

## Other environments

Other environments (currently test and staging) should be consistent with production. The domain `staging.communities.gov.uk` is currently in use, so we plan to use `stage.communities.gov.uk` and `test.communities.gov.uk`.

Setting this up the same as production requires DLUHC to maintain a few extra records, but means the environments will be consistent.

So:

* `internal.stage.communities.gov.uk` delegated to Route53
* ACM validation records for an SSL certificate on `*.stage.communities.gov.uk`, `*.delta.stage.communities.gov.uk`
* `delta.stage.communities.gov.uk` CNAME to `delta.internal.stage.communities.gov.uk` etc.
* Same for `test.communities.gov.uk`
