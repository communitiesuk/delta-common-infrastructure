import-module activedirectory
# Generate a bunch of users to bring staging closer to production for performance testing
# This depends on a file orgs.csv. This can be the csv downloaded from the admin /organisations page
# Change <password here> to something secure before running
$orgs = import-csv "orgs.csv"
foreach ($i in 1..1) {
  $firstName = "Stacy$i"
  $surname = "Fakename"
  $email = "$firstName$surname@example.com"
  $id = "$firstName$surname!example.com" 
  $samAccountName = "$firstName$surname"
  $numberOfOrgs = $orgs.length
  $orgId = $orgs[$i % $numberOfOrgs].'organisation-id'
  New-ADUser -SamAccountName $samAccountName `
      -AccountPassword $(ConvertTo-SecureString -AsPlainText <password here> -Force) `
      -UserPrincipalName ("$id@dluhcdata.local") -Name $id -GivenName $firstName `
      -Surname $surname -EmailAddress ($email) `
      -Enabled $true -Path "CN=Datamart,OU=Users,OU=dluhcdata,DC=dluhcdata,DC=local"

  # Add roles
  foreach ($role in @("user", "data-providers", "testaccess")) {
    try {
      New-ADGroup -Name "datamart-delta-$role-$orgId" -Path "CN=datamart-delta,OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local" -GroupScope Global
      Write-Host "Added Group: datamart-delta-$role-$orgId"
    }
    Add-ADGroupMember -Identity "datamart-delta-$role" $samAccountName
    Add-ADGroupMember -Identity "datamart-delta-$role-$orgId" $samAccountName
  }
  Write-Host "Added User: $id"
}
