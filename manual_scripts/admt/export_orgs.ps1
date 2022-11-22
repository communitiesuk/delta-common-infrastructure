# Not sure this is necessary. There is code that references this set of OUs but it doesn't seem to do much.
# Skipping this for now and we will see if the staging site works.

Get-ADOrganizationalUnit -SearchBase 'OU=Delta-Organizations,DC=dclg-stag-eclaim,DC=local' -Filter 'Name -like "*"' | Select-Object Name, businessCategory, DisplayName | Export-Csv -Path .\delta_orgs.csv -NoTypeInformation

# Remove the Delta-Organizations OU itself from the top of the list.
