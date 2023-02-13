ldifde -f ous.ldf -r “(objectClass=organizationalUnit)” -l "objectClass,Name,DisplayName,businessCategory" -d "OU=Delta-Organizations,DC=datamart,DC=local"
(Get-Content 'ous.ldf').replace('DC=datamart,DC=local', 'OU=dluhcdata,DC=dluhcdata,DC=local') | Set-Content 'ous.ldf'
