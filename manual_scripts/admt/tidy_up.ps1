$targetBase = "OU=dluhcdata,DC=dluhcdata,DC=local"

# Move any users in the "Groups" OU to the correct "Users" OU
Get-AdUser -Filter * -SearchBase "OU=Groups,$targetBase" | ForEach-Object {
    Write-Host "Move ad user" $_.Name
    # Move user to target OU
    Move-ADObject -Identity $_.ObjectGUID -TargetPath "CN=Datamart,OU=Users,$targetBase"
} 

# You could manually delete service users such as superuser, datamart-biz-stag01, cpm-biz-stag01

# ADMT sets –changepasswordatlogonto true. Undo that.
Get-ADUser -Filter {pwdlastset -eq 0} –searchbase "OU=Users,$targetBase" | Set-ADUser –ChangePasswordAtLogon $false

# Set PasswordNeverExpires for any migrated service users that we want to keep
$serviceUsers = "sap-admin", "soap-ui-sap-admin", "cpm-admin", "achadmin-dclg"
Foreach($user in $serviceUsers){
    Get-ADUser -Identity $user | Set-ADUser -PasswordNeverExpires $true
}
