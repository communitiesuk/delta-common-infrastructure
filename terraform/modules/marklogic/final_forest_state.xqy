xquery=
xquery version "1.0-ml";

declare namespace h = "http://marklogic.com/xdmp/status/host";
declare namespace f = "http://marklogic.com/xdmp/status/forest";

let $forests-in-incorrect-state := (
    for $forest-id in xdmp:forests()
      let $current-forest-status := xdmp:forest-status($forest-id)
      let $current-name := $current-forest-status/(f:forest-name)
      let $current-state := $current-forest-status/(f:state)
      let $rep-forest := (fn:contains($current-name, "rep1") or fn:contains($current-name, "replica"))
      return
        if (($rep-forest and $current-state = "sync replicating") or ($current-state = "open" and fn:not($rep-forest)))
        then ()
        else fn:concat($current-name, ":", $current-state)
)

let $success := fn:empty($forests-in-incorrect-state)
let $output :=
    if ($success)
    then "ALL_FORESTS_IN_CORRECT_STATE"
    else string-join($forests-in-incorrect-state,",")
return ("output:" || $output)
