$targetBase = "OU=dluhcdata,DC=dluhcdata,DC=local"

# Move any users in the "Groups" OU to the correct "Users" OU
Get-AdUser -Filter * -SearchBase "OU=Groups,$targetBase" | ForEach-Object {
    Write-Host "Move ad user" $_.Name
    # Move user to target OU
    Move-ADObject -Identity $_.ObjectGUID -TargetPath "CN=Datamart,OU=Users,$targetBase"
} 

# Manually delete service users such as superuser, datamart-biz-stag01, cpm-biz-stag01

# ADMT sets –changepasswordatlogon to true. Undo that for users that had it false in Datamart (using )

# Get Users who do not need to reset password, using pwdlastset as a proxy
$deltaGroup = Get-ADGroup datamart-delta-user -Server $server
Get-AdUser -Filter {pwdlastset -ne 0 -and MemberOf -eq $deltaGroup.DistinguishedName} -SearchBase "CN=datamart,CN=Users,DC=datamart,DC=local" -Server datamart.local | Select-Object @{n='SourceName';e={$_.SamAccountName}} | Export-Csv -Path .\users-no-pwd-reset.csv -NoTypeInformation
$users = import-csv "users-no-pwd-reset.csv"
Foreach($user in $users){
    Set-ADUser –ChangePasswordAtLogon $false -Identity $user.SourceName
}


# Set PasswordNeverExpires for any migrated service users that we want to keep
$serviceUsers = "sap-admin", "soap-ui-sap-admin", "cpm-admin", "achadmin-dclg"
Foreach($user in $serviceUsers){
    Get-ADUser -Identity $user | Set-ADUser -PasswordNeverExpires $true
}
