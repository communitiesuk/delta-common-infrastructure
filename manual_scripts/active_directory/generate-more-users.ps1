import-module activedirectory
# Generate a bunch of users to bring staging closer to production for performance testing
# This depends on a file orgs.csv. This can be the csv downloaded from the admin /organisations page
#
# Change <password here> to something secure before running
# If running against dev/test environments, change instances of "dluhcdata" to "dluhctest"
# This also depends on an access group called "testaccess" existing. Change that if you want a different access group.

$orgs = import-csv "orgs.csv"
foreach ($i in 1..10000) {
  $firstName = "Stacy$i"
  $surname = "Fakename"
  $email = "$firstName$surname@example.com"
  $id = "$firstName$surname!example.com" 
  $samAccountName = "$firstName$surname"
  $numberOfOrgs = $orgs.length
  $orgId = $orgs[$i % $numberOfOrgs].'organisation-id'
  New-ADUser -SamAccountName $samAccountName `
      -AccountPassword $(ConvertTo-SecureString -AsPlainText "nw5zP823iiSS" -Force) `
      -UserPrincipalName ("$id@dluhcdata.local") -Name $id -GivenName $firstName `
      -Surname $surname -EmailAddress ($email) -Enabled $true `
      -Path "CN=Datamart,OU=Users,OU=dluhcdata,DC=dluhcdata,DC=local" `
      -OtherAttributes @{
          'comment'='Created via generate-more-users script'
      }

  # Add roles
  foreach ($role in @("user", "data-providers", "testaccess")) {
    try {
      New-ADGroup -Name "datamart-delta-$role-$orgId" -Path "CN=datamart-delta,OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local" -GroupScope Global
      Write-Host "Added Group: datamart-delta-$role-$orgId"
    } catch {}
    Get-ADGroup -filter "name -eq `"datamart-delta-$role`"" | Add-ADGroupMember -Members $samAccountName
    Get-ADGroup -filter "name -eq `"datamart-delta-$role-$orgId`"" | Add-ADGroupMember -Members $samAccountName
  }
  Write-Host "Added User: $id"
}
