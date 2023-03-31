xquery=
xquery version "1.0-ml";

declare namespace h = "http://marklogic.com/xdmp/status/host";
declare namespace f = "http://marklogic.com/xdmp/status/forest";

let $all-forests-in-correct-state := (
    for $forest-id in xdmp:forests()
      let $current-forest-status := xdmp:forest-status($forest-id)
      let $current-name := $current-forest-status/(f:forest-name)
      let $current-state := $current-forest-status/(f:state)
      let $rep-forest := (fn:contains($current-name, "rep1") or fn:contains($current-name, "replica"))
      return
        if (($rep-forest and $current-state = "sync replicating") or ($current-state = "open" and fn:not($rep-forest)))
        then ()
        else "false"
)

let $failed := ($all-forests-in-correct-state = "false")
let $output :=
    if ($failed)
    then "ERROR"
    else "ALL_FORESTS_IN_CORRECT_STATE"
return ("output:" || $output)
