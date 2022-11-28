$orgs = import-csv "delta_orgs.csv"


Foreach($org in $orgs){       
    New-ADOrganizationalUnit -Name $org.Name -Path "OU=DELTA-Organizations,OU=dluhcdata,DC=dluhcdata,DC=local"
}
