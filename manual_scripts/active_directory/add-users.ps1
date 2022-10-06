import-module activedirectory
$users = import-csv "users.csv"
$usersToGroups = import-csv "users-to-groups.csv"

Foreach($user in $users){       
    New-ADUser -SamAccountName $user.SamAccountName -DisplayName $user.DisplayName `
        -AccountPassword $(ConvertTo-SecureString -AsPlainText $user.Password -Force) `
        -UserPrincipalName $user.UserPrincipalName -Name $user.Name -Enabled $true `
        -Path $user.Path
    Write-Host "Added User: $user.Name"
}
 
Foreach($user in $usersToGroups){       
    Add-ADGroupMember -Identity $usersToGroups.Group $usersToGroups.AccountName
    Write-Host "Added Group Member: $usersToGroups.Group $usersToGroups.AccountName"
}
 