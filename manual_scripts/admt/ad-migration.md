## Active Directory Migration Tool setup

Optional, but recommended:

* Make sure the AD Management Server is at least a t3.xlarge, apply that change with terraform if necessary.
* Install Firefox (note that the AD server is behind the Network Firewall, so most sites will not load)

  ```powershell
  Invoke-WebRequest "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US" -OutFile firefox.exe
  .\firefox.exe
  ```

### Domain setup

RDP into the AD Management Server as domain admin.

Following the instructions here: <https://aws.amazon.com/blogs/security/how-to-migrate-your-on-premises-domain-to-aws-managed-microsoft-ad-using-admt/> or [AWS documentation](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_tutorial_setup_trust_prepare_onprem.html) for prerequisites

* Open up the security groups and ACL. Easiest to allow all traffic. DCs definitely need to be able to send DNS requests to each other.
  * Done in terraform
* Run through the other prerequisites, check Windows Firewall and that Kerberos pre-authentication enabled, was all fine on our side
* Configure conditional DNS forwarders on both sides and make sure you can resolve both domains using either AD - I'm not sure this is required for the managed side since you set them up when you create the trust, but I did it anyway
* Set the Local Security Policy for Named pipes as detailed here, I think it's the default: <https://docs.aws.amazon.com/directoryservice/latest/admin-guide/before_you_start.html>
* Set up the two-way forest trust using Active Directory Domains and Trusts on the non-managed side and the AWS console on the managed side (currently not in terraform)
* Log in as an admin of the source domain, and add the admin user of the target domain to the Administrators group (the memberOf tab is a bit buggy for this, use the members list of the group instead). You can do this from an Admin powershell:
```
$User = Get-ADUser -Identity "CN=Admin,OU=Users,OU=dluhcdata,DC=dluhcdata,DC=local" -Server "dluhcdata.local"
Add-ADGroupMember -Identity Administrators -Members $User -Server "<source domain>.local"
```
* We'll then use the target domain admin for the rest of the process, as they now have permissions across both domains
* Continue with the guide to set up PES. [Direct download link](https://download.microsoft.com/download/a/1/0/a10798d3-cc25-4c32-a393-c06cd9f5d854/pwdmig.msi). Run the pwdmig.msi in admin mode (e.g. from an admin powershell terminal).

You also need to keep the users' "guid" the same. ObjectGUID can't be migrated or manually set, so we instead need to store it in a new attribute. Upload the imported-guid.ldif file as a schema change to the AWS managed directory. 

### Installation

Install SQL Server Express 2019.

```powershell
Write-Host "Downloading SQL Server Express 2019..."
$Path = $env:TEMP
$Installer = "SQL2019-SSEI-Expr.exe"
$URL = "https://go.microsoft.com/fwlink/?linkid=866658"
Invoke-WebRequest $URL -OutFile $Path\$Installer

Write-Host "Installing SQL Server Express..."
Start-Process -FilePath $Path\$Installer -Args "/ACTION=INSTALL /IACCEPTSQLSERVERLICENSETERMS /QUIET" -Verb RunAs -Wait
Remove-Item $Path\$Installer
```

Download and install ADMT from here <https://www.microsoft.com/en-us/download/details.aspx?id=56570>, direct link: <https://download.microsoft.com/download/9/1/5/9156937F-1DF7-4734-9BEB-5F0A4400B29E/admtsetup32.exe>

When it asks for a database server to use, use `.\SQLEXPRESS`.

Set up PES on the source domain, step 3 here: <https://aws.amazon.com/blogs/security/how-to-migrate-your-on-premises-domain-to-aws-managed-microsoft-ad-using-admt/>. Direct download link: <https://download.microsoft.com/download/a/1/0/a10798d3-cc25-4c32-a393-c06cd9f5d854/pwdmig.msi>

### Running ADMT

Use the scripts in manual_scripts/admt/
* Update ADMT's exclusion list so that it doesn't exclude the "mail" attribute. To do this, copy the update_exclusion.vbs script onto the server and run `c:\windows\syswow64\cscript.exe update_exclusion.vbs` from an administrator command prompt.
* Import all groups by updating `get_groups.ps1` with the correct variables at the top, and then run it on the migration server to generate include files.
* Run ADMT (called Active Directory Migration Tool from the Start menu) and start the Group migration wizard. Use the `groups-includefile.csv` include file. Target `OU=Groups,...` for both source and target domains. Select the option to include users. We import users as part of the group migration because there are too many users in production for powershell to create a users include file based on membership of datamart-delta-user
* Run another ADMT Group migration. This time use `nested-groups-includefile.csv`. Target `CN=datamart-delta,OU=Groups...`.
* Run an ADMT user migration. Use the `registration-requests-includefile.csv` include file.
  * Target `CN=DeltaRegistrationRequests,OU=Users,...` in the target domain.
  * Under "conflict management" check the box for moving merged objects to the target OU.
* Run an ADMT user migration selecting any other users required (such as `achadmin-dclg` for eclaims to access CPM)
* Put the correct service user names in tidy_up.ps1 and then run it.
  * You can search for service users by check which users have non-expiring passwords, eg:
  ```
  $group = Get-ADGroup "datamart-delta-user"
  get-AdUser -filter {MemberOf -eq $group.DistinguishedName -and passwordNeverExpires -eq 'true'} -Server datamart.local -Properties MemberOf
  ```
  * Service users that should be definitely be deleted: superuser, delta-superuser, datamart-app-admin, delta-service, cpm-biz-prod01, cpm-app-user, admin-dclg (has a different SAM id), delta-reports-user
Make sure sap-admin is a member of `datamart-cpm-soap-api`

For E-Claims access to the CPM API, these users need to have been imported and added to the `datamart-user` group:
* In staging, `cpm-admin`
* In production, `achadmin-dclg`

### Importing OUs

This cannot be done with ADMT. To import the OUs inside OU=Delta-Organizations:
* Run the export_delta_orgs.ps1 script on the source DC to generate an export file
* Edit the output file, deleting the top entry (which refers to OU=Delta-Organizations itself)
* Copy the file to our AD management server
* Run `ldifde -i -f ous.ldf` to import it

### Incremental migration

Run `get_recently_changed.ps1` to generate include files for recently changed groups and users.
* Run the group migration WITHOUT including any users
* Run the user migration
* Run tidy_up.
