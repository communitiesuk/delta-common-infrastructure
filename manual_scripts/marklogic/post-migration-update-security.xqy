xquery version "1.0-ml"; 
 
import module namespace sec = "http://marklogic.com/xdmp/security" 
      at "/MarkLogic/security.xqy";
 
(:~
 : Update role external names:
:)
(
for $role-id in xdmp:roles()
  let $role-name := sec:get-role-names($role-id)[1]
  let $role-external-names := sec:role-get-external-names($role-name)
  where not(empty($role-external-names))
  return sec:role-set-external-names($role-name,($role-name, concat("CN=", $role-name, ",OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local")))
),
   
(:~
 : Delete Datamart service users
:)
let $users := (
"esif-user",
"becky.carter",
"ML10_London_Production",
"tfam-website-user",
"Lorraine.Gillespie",
"thayine.kokulan",
"tfis-jenkins",
"fcf-administrator",
"hclic-user",
"david.maymiller",
"core-administrator",
"core-coordinator",
"Adimulam",
"cpm-user",
"dan.smith",
"bdang",
"ben.ward",
"justin.ruth",
"admin-cpm",
"delta-automated-service-user",
"infostudio-admin",
"fcf-coordinator",
"jawahar.mariappan",
"luke.marrai",
"bala.natarajan",
"stephen.jackson",
"carine.kong",
"jess.gilbert",
"cms-content-administrator",
"richard.crichton",
"fcf-evaluator",
"Jack.Heywood",
"nagaraja.joisa",
(: "ed.outhwaite", Keeping "ed" and "ed.outhwaite" for now :)
"dclg-minimal-privilege-user",
"dclg-user",
"graham.dagless",
"admin-eclaims",
"rhianna.mcgill",
"DATAMART_ADMIN_ML10_PRODUCTION",
"arcus-admin",
"core-data-protection",
"karlmarx.rajangam",
"lincoln.stone",
"datamart-user",
"datamart-delta-admin-user",
"rachael.booth",
"hclic.extract",
"core-data-provider",
"iain.monro",
"call-close-user",
"core-private-data-downloader",
"mark.rainbird",
"fcf-minimal-privilege-user",
"matt.steel",
"fcf-data-provider",
"adam.harrowven",
"DATAMART_ML_ADMIN_PROD",
"dwp-user",
"Victoria.Holland",
"payments-user"
)
return for $user in $users
  return sec:remove-user($user)
