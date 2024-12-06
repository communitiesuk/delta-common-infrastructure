Get-ADGroup -Filter * -searchbase "CN=datamart-delta,OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local" -P
roperties * |
Select-Object Name, description, @{n='info';e={ConvertFrom-Json($_.info)}} |
Select-Object Name, @{n='Display';e={$_.info.registrationDisplayName}}, @{n='Type';e={$_.description}}, @{n='Self-ser
vice external';e={$_.info.enableOnlineRegistration}}, @{n='Self-service internal';e={$_.info.enableInternalUser}} |
Export-Csv -Path .\groups-report.csv -NoTypeInformation
