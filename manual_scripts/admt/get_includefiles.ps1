# This script generates lists of entities you want to migrate, known as an "include file".
# It generates two lists of groups (to be imported to different locations) and a list of "registration requests"
$sourceBase = "DC=datamart,DC=local"
$server = "datamart.local"

# Migrate groups:
# To use the file run a group migration and tick the box to include migrating any members.
Get-ADGroup -SearchBase "OU=Groups,$sourceBase" -Filter 'Name -like "datamart-delta*"' -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\groups-includefile.csv -NoTypeInformation
Get-ADGroup -SearchBase "CN=datamart-delta,OU=Groups,$sourceBase" -Filter * -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\nested-groups-includefile.csv -NoTypeInformation

# Migrate DeltaRegistrationRequests
# To use it, run a user migration
Get-AdUser -SearchBase "CN=DeltaRegistrationRequests,CN=Users,$sourceBase" -Filter *  -Server $server | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\registration-requests-includefile.csv -NoTypeInformation
