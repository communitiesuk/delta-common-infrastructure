# This file generates a list of entities you want to migrate, known as an "include file".
# We just list the security groups to migrate and tick the box to include migrating any members.
$sourceBase = "DC=dclg-stag-eclaim,DC=local"

# Migrate groups:
Get-ADGroup -SearchBase "OU=Groups,$sourceBase" -Filter 'Name -like "datamart-delta*"' | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\groups-includefile.csv -NoTypeInformation
Get-ADGroup -SearchBase "CN=datamart-delta,OU=Groups,$sourceBase" -Filter * | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\nested-groups-includefile.csv -NoTypeInformation

# Migrate DeltaRegistrationRequests
Get-AdUser -SearchBase "CN=DeltaRegistrationRequests,CN=Users,$sourceBase" -Filter *  | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\registration-requests-includefile.csv -NoTypeInformation
