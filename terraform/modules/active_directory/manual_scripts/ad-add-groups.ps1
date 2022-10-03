import-module activedirectory

New-ADObject -Name "Users" -Type "container" -Path "OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADObject -Name "Datamart" -Type "container" -Path "CN=Users,OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=dluhcdata,DC=dluhcdata,DC=local"

$groups = import-csv "ad-groups.csv"

Foreach($group in $groups){       
    New-ADGroup -Name $group.Group -Path "OU=Groups,DC=dluhcdata,DC=local" -GroupScope Global
	Write-Host "Added Group: $group.Group"
}
 