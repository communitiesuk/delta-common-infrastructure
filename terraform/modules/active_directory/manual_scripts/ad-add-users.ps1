import-module activedirectory
$users = import-csv "ad-users.csv"

New-ADUser -SamAccountName joe.bloggs -DisplayName "Joe Bloggs" -AccountPassword $(ConvertTo-SecureString -AsPlainText "password" -Force) -UserPrincipalName "joe.bloggs@example.com" -Name "Joe Bloggs"

Foreach($user in $users){       
	Add-ADGroupMember -Identity $user.Group $user.AccountName >> add-group-members-log.txt
	Write-Host "Added Group Member: $user.Group $user.AccountName"
}
 