# Active Directory Management

## SSH tunnel

To connect to the AD servers you will first need to forward port 3389 through the SSH bastion.

For setup see the top level README, then port forward with

```sh
ssh <username>@$(terraform output -raw bastion_dns_name) -L localhost:3388:$(terraform output -raw ad_management_server_private_ip):3389
```

then connect with RDP to localhost:3388

## RDP to management server as directory admin:

* Username: dluhcdata.local\admin
* Password: from output directory_admin_password

### RDP to CA server

If you need to connect to the CA server, RDP to the management server first and then from there RDP to the CA.

* Username: Administrator
* Password: get password data and decrypt it

## First time setup - install management tools:

### For general AD management

From [AWS documentation](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_install_ad_tools.html):

* Open `Server manager`
* Add Roles and Features
* On the "Features" page of the wizard, open up `Remote Server Administration Tools` -> `Role Administration Tools` and tick both `AD DS and AD LDS Tools` and `DNS Server Tools`

### For migrating data between AD domains

From [AWS documentation](https://aws.amazon.com/blogs/security/how-to-migrate-your-on-premises-domain-to-aws-managed-microsoft-ad-using-admt/) for prerequisites for AD migration:

* Download SQL Server Express: <https://www.microsoft.com/en-au/sql-server/sql-server-downloads>
* Download ADMT: <https://www.microsoft.com/en-us/download/details.aspx?id=56570>

## Troubleshooting

### You can also connect as the ec2 server admin:

* Username: `Administrator`
* Password: `ad_management_server_password` terraform output

### View SSM result

Terraform is unaware of an aws_ssm_association failing to run.

* Run `aws ssm list-commands` to see the status.
* RDP to the server to find the logs. Check under `C:\ProgramData\Amazon\SSM`
