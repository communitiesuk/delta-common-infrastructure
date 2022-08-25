# Setup

## RDP to management server as directory admin:

* Username: dclgsec.local\Administrator
* Password: from input variable directory_admin_password

## First time setup - install management tools:

From [AWS documentation](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_install_ad_tools.html):

* Open `Server manager`
* Add Roles and Features
* On the "Features" page of the wizard, open up `Remote Server Administration Tools` -> `Role Administration Tools` and tick both `AD DS and AD LDS Tools` and `DNS Server Tools`

From [AWS documentation](https://aws.amazon.com/blogs/security/how-to-migrate-your-on-premises-domain-to-aws-managed-microsoft-ad-using-admt/) for prerequisites for AD migration:

* Download SQL Server Express: https://www.microsoft.com/en-au/sql-server/sql-server-downloads
* Download ADMT: https://www.microsoft.com/en-us/download/details.aspx?id=56570

# Troubleshooting

## To troubleshoot, you can also connect as the ec2 server admin:

* Username: `Administrator`
* Password: decrypt the `ad_management_server_password` output using the relevant private key or find the password from centralised secret management.

> To decrypt the password with a private key, decode with `base64 -d` and then run `openssl rsautl -decrypt -in input.txt -out output.txt -inkey ~/.ssh/id_rsa`