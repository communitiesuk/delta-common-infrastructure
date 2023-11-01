# Active Directory Management

## SSH tunnel

To connect to the AD servers you will first need to forward port 3389 through the SSH bastion.

For setup see the top level README, then port forward with

```sh
ssh <username>@$(terraform output -raw bastion_dns_name) -L localhost:3388:ad_management.vpc.local:3389
```

then connect with RDP to localhost:3388

## RDP to management server as directory admin

* Username: dluhcdata.local\admin
* Password: from AWS secrets manager, e.g. `staging-active-directory-admin-password`. This is because Terraform does not pick up the change when you reset the password.
  * If it is not in secrets manager, it may be in Terraform state from the output `directory_admin_password`

### RDP to CA server

If you need to connect to the CA server, RDP to the management server first and then from there RDP to the CA.

* Username: Administrator
* Password: get password data and decrypt it

## First time setup

### Install AD management tools

This should happen automatically via the instance's user data, but you can also perform the installation manually. From [AWS documentation](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_install_ad_tools.html):

* Open `Server manager`
* Add Roles and Features
* On the "Features" page of the wizard, open up `Remote Server Administration Tools` -> `Role Administration Tools` and tick both `AD DS and AD LDS Tools` and `DNS Server Tools`

### Set up DNS forwarding

From [AWS documentation](https://aws.amazon.com/blogs/networking-and-content-delivery/integrating-your-directory-services-dns-resolution-with-amazon-route-53-resolvers/).

RDP to the AD management server, and open up the DNS Manager application. Enter the IP address of one of the DNS servers. You can get their IP addresses from `terraform output ad_dns_servers`. Right click on "Forwarders" and ensure there is a single forwarder with the IP address of the Amazon Provided DNS server, which is the VPC's base IP address + 2, i.e. `*.*.0.2`.

Or using PowerShell

```powershell
Set-DnsServerForwarder -ComputerName <dns-server> -IpAddress x.x.0.2
```

Do the same for the other server and check that `nslookup secretsmanager.eu-west-1.amazonaws.com` returns an IP address inside the VPC.

Only the management server and CA server use the Domain Controllers as DNS servers.
Other instances within the VPC use Amazon provided DNS and this module configures a private Route53 zone that points the domain (dluhcdata.local) at an NLB that forwards LDAP(S) requests to the DCs. This NLB is sticky which helps mitigate problems due to replication lag.

## Troubleshooting

### You can also connect as the ec2 server admin

* Username: `Administrator`
* Password: `ad_management_server_password` terraform output

### View SSM result

Terraform is unaware of an aws_ssm_association failing to run.

* Run `aws ssm list-commands` to see the status.
* RDP to the server to find the logs. Check under `C:\ProgramData\Amazon\SSM\Logs`

### CA Server setup

* To track progress of the new server being provisioned, see logs from the CA server "QuickStart" SSM document in CloudWatch
* If replacing the CA server, delete all traces of the old one:
  * Before destroying the old CA server, revoke its certificates by connecting with Remote Desktop, open the Certification Authority app, go to issued certificates, right click and revoke. Then publish the CRL.
  * Delete the "computer" named CSRV{env} from Active Directory via the "Users and Computers" app
  * Delete all the AD objects named CSRV{env} inside Services -> Public Key Services, via the "Sites and Services" app (you need to enable the services folder from the View menu)
  * Delete the `LdapOverSSL-QS` certificate template from: Services -> Public Key Services -> Certificate Templates
  * Delete the certificate from inside the NtAuthCertificates object via this command (set DC correctly): `certutil -viewdelstore "ldap:///CN=NtAuthCertificates,CN=Public Key Services,CN=Services,CN=Configuration,DC=dluhcdata,DC=local?cACertificate?base?objectclass=certificationAuthority"`
  * Now you can delete and recreate the cloudformation template

### Update DNS servers

You may have to update the DNS servers manually to point to the Domain Controllers as we no longer advertise them over DHCP.

Log into the server and in an admin PowerShell update:

```powershell
Get-DnsClientServerAddress
Set-DNSClientServerAddress "Ethernet 2" -ServerAddresses ("10.0.5.12", "10.0.4.251")
```

Where "Ethernet 2" matches the interface name returned by the first command and the IP addresses are the domain controller for that environment's DCs, you can get these from the `ad_dns_servers` Terraform output or the AWS console under Directory Services.
