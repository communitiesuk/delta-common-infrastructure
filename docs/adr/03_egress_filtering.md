# Egress filtering

## Aims

We will filter outbound traffic from the VPC in order to mitigate certain classes of vulnerabilities and limit data exfiltration.
This will need to be flexible enough to allow the existing applications to install and run with minimal modification.

Note this only applies to connections initiated from within the VPC's private subnets, public subnets and return traffic via load balancers will not be affected.

## Existing infrastructure

The existing DataMart infrastructure filters egress traffic using Squid proxy.

## Constraints

We need to be able to filter HTTP and TLS traffic by domain. IP and port allowlisting will not be sufficient.

Our resources will need to be able to access S3 and other AWS services.

## Design

### AWS services

Allowing unrestricted access to S3 would undermine the rest of the filtering to a large extent, as buckets could be attacker controlled.
We will instead use VPC endpoints for S3 (and other AWS services) with policies to control what buckets can be accessed.

### AWS Network Firewall

We investigated AWS Network Firewall as a managed alternative to Squid proxy.

Advantages of AWS Network Firewall:

* No server to manage and patch
* Native integration with AWS CloudWatch
* Other potential advantages, we have largely disregarded these from our decision since we do not expect to need them in the short term, but they could be useful in the future
  * Can easily scale to multiple endpoints for redundancy and handling large amounts of traffic
  * Integration with other AWS services, for example, AWS Organisations managing firewall policy and logging across accounts

Advantages of Squid Proxy:

* Used by the current infrastructure, so we know it works
* Cost, at time of writing the Squid AMI is $36/month plus the cost of an instance, whereas AWS Network Firewall is approx $250/month
  * For non-production environments especially where Squid could run on a small instance this could be ~$2000/year/environment

We do not have significant existing familiarity with either, both have a moderately complicated Firewall rule configuration language.

#### Decision

We resolved that the reduction in maintenance effort would likely offset the cost of using AWS Network Firewall, so are proceeding with that pending agreement with the Cyber team.

### Filtering source precision

We could filter traffic based on source IP within the VPC to different resolutions (VPC, subnet, instance).

We have resolved to filter traffic based on subnet, and have separate subnets for each service within the VPC.
This will:

* be more work to configure
* allow for finer grained security controls
* enable us to easily + safely remove rules when a service is decommissioned, which we're planning to do for some components long term
