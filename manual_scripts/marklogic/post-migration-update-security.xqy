xquery version "1.0-ml"; 
 
import module namespace sec = "http://marklogic.com/xdmp/security" 
      at "/MarkLogic/security.xqy";
 
(:~
 : Update role external names:
:)
 
for $role-id in xdmp:roles()
  let $role-name := sec:get-role-names($role-id)[1]
  let $role-external-names := sec:role-get-external-names($role-name)
  where not(empty($role-external-names))
  return sec:role-set-external-names($role-name,($role-name, concat("CN=", $role-name, ",OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local")))

   
(:~
 : Delete Datamart service users
:)
declare variable $users := (
  "adimulam",
  "ashley.cousins",
  "bala.natarajan",
  "cs.support",
  "DELTA_ML-ADMIN_STAGING",
  "delta-user",
  "graham.dagless",
  "jawahar.mariappan",
  "Justin.D",
  "justin.struth",
  "mark.rainbird",
  "matt.steel",
  "victoria.holland",
  "vinod.sathyamoorthy"
  (: This is just staging users currently :)
);
for $user in $users
  return sec:remove-user($user)
