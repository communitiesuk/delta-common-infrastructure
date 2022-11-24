import-module activedirectory

New-ADObject -Name "Datamart" -Type "container" -Path "OU=Users,OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADObject -Name "DeltaRegistrationRequests" -Type "container" -Path "OU=Users,OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADObject -Name "datamart-delta" -Type "container" -Path "OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local"
New-ADOrganizationalUnit -Name "DELTA-Organizations" -Path "OU=dluhcdata,DC=dluhcdata,DC=local"

$groups = import-csv "groups.csv"

Foreach($group in $groups){       
    New-ADGroup -Name $group.Group -Path "OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local" -GroupScope Global
    Write-Host "Added Group: $group.Group"
}
 