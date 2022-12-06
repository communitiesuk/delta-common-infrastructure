ldifde -f ous.ldf -r “(objectClass=organizationalUnit)” -l "objectClass,Name,DisplayName,businessCategory" -d "OU=Delta-Organizations,DC=dclg-stag-eclaim,DC=local"
(Get-Content 'ous.ldf').replace('DC=dclg-stag-eclaim,DC=local', 'OU=dluhcdata,DC=dluhcdata,DC=local') | Set-Content 'ous.ldf'
