# This file generates a list of entities you want to migrate, known as an "include file".
# We just list the security groups to migrate and tick the box to include migrating any members.
$sourceBase = "DC=datamart,DC=local"
$server = "datamart.local"

# Migrate groups:
Get-ADGroup -SearchBase "OU=Groups,$sourceBase" -Filter 'Name -like "datamart-delta*"' -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\groups-includefile.csv -NoTypeInformation
Get-ADGroup -SearchBase "CN=datamart-delta,OU=Groups,$sourceBase" -Filter * -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\nested-groups-includefile.csv -NoTypeInformation

# Migrate DeltaRegistrationRequests
Get-AdUser -SearchBase "CN=DeltaRegistrationRequests,CN=Users,$sourceBase" -Filter *  -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\registration-requests-includefile.csv -NoTypeInformation

# Get Users who do not need to reset password, using pwdlastset as a proxy
$deltaGroup = Get-ADGroup datamart-delta-user -Server $server
Get-AdUser -Filter {pwdlastset -ne 0 -and MemberOf -eq $deltaGroup} -SearchBase "CN=datamart,CN=Users,DC=datamart,DC=local" -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\users-no-pwd-reset.csv -NoTypeInformation