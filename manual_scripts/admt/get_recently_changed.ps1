# This file generates a list of entities you want to migrate, known as an "include file".
# We just list the security groups to migrate and tick the box to include migrating any members.
$sourceBase = "DC=datamart,DC=local"
$server = "datamart.local"
$date = (Get-Date).AddDays(-11)

# Migrate groups:
Get-ADGroup -SearchBase "OU=Groups,$sourceBase" -Filter {WhenChanged -gt $date -and Name -like "datamart-delta*"} -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\recent-groups-includefile.csv -NoTypeInformation
Get-ADGroup -SearchBase "CN=datamart-delta,OU=Groups,$sourceBase" -Filter {WhenChanged -gt $date} -Server $server  | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\recent-nested-groups-includefile.csv -NoTypeInformation

# Migrate users:
$deltaGroup = Get-ADGroup datamart-delta-user -Server $server
Get-AdUser -SearchBase "CN=Users,$sourceBase" -Filter {WhenChanged -gt $date -and MemberOf -eq $deltaGroup.DistinguishedName} -Server $server| Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\recent-users-includefile.csv -NoTypeInformation

# I expect these to be empty
Get-AdUser -SearchBase "CN=DeltaRegistrationRequests,CN=Users,$sourceBase" -Filter {WhenChanged -gt $date}  -Server $server
Get-ADOrganizationalUnit -SearchBase "OU=Delta-Organizations,DC=datamart,DC=local" -Filter {WhenChanged -gt $date}  -Server $server

