# This file generates a list of entities you want to migrate, known as an "include file".
# We just list the security groups to migrate and tick the box to include migrating any members.
$sourceBase = "DC=dclg-stag-eclaim,DC=local"

# Migrate groups:
Get-ADGroup -SearchBase "OU=Groups,$sourceBase" -Filter 'Name -like "datamart-delta-*"' | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\groups-includefile.csv -NoTypeInformation
# Start a group migration, targeting OU=Groups for both source and target domains. Select the option to include users
# Import users as part of the group migration because there seem to be too many users in production for powershell to create the include file

# Migrate DeltaRegistrationRequests
Get-AdUser -SearchBase "CN=DeltaRegistrationRequests,CN=Users,$sourceBase" -Filter *  | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\registration-requests-includefile.csv -NoTypeInformation
# Use ADMT to start a user migration, targeting CN=DeltaRegistrationRequests,OU=Users...