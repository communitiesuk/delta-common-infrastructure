xquery=
xquery version "1.0-ml";

declare namespace h = "http://marklogic.com/xdmp/status/host";
declare namespace f = "http://marklogic.com/xdmp/status/forest";

let $all-forests-open-or-sync-replicating := (
    for $forest-id in xdmp:forests()
      let $current-state := xdmp:forest-status($forest-id)/(f:state)
      return
        if ($current-state = "sync replicating" or $current-state = "open")
        then ()
        else "false"
)

let $must-wait := ($all-forests-open-or-sync-replicating = "false")
let $output :=
    if ($must-wait)
    then "WAITING_FOR_REPLICATION"
    else "READY_FOR_RESTART"
return ("output:" || $output)
