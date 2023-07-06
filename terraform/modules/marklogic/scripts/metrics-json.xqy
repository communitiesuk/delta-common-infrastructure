xquery version "1.0-ml";

declare namespace hs = "http://marklogic.com/xdmp/status/host";
declare namespace ss = "http://marklogic.com/xdmp/status/server";
declare namespace forest = "http://marklogic.com/xdmp/status/forest";
declare namespace dluhc = "http://levellingup.gov.uk";

declare %private function dluhc:metric($metric as xs:string, $value as item()) as map:map {
  map:new((
    map:entry("metric", $metric),
    map:entry("value", $value)
  ))
};

declare %private function dluhc:database-document-count($database-name as xs:string) as xs:long {
  let $database := xdmp:database($database-name)
  let $forest-ids := xdmp:database-forests($database)
  let $forest-stats := for $forest-id in $forest-ids
    let $forest-counts := xdmp:forest-counts($forest-id, ("document-count"))
    order by $forest-counts/forest:forest-name/text()
    return $forest-counts
  return fn:sum(xs:int($forest-stats/forest:document-count))
};

declare %private function dluhc:security-summary() as map:map* {
  xdmp:invoke-function(
    function() {
      (
        dluhc:metric("sec-num-users", fn:count(//sec:user)),
        dluhc:metric("sec-num-roles", fn:count(//sec:role))
      )
    },
    <options xmlns="xdmp:eval">
      <database>{xdmp:security-database()}</database>
    </options>
  )
};

declare %private function dluhc:payments-summary() as map:map* {
  xdmp:invoke-function(
    function() {
      (
        dluhc:metric("cpm-total-payments", fn:count(fn:collection("payment"))),
        dluhc:metric("cpm-total-transactions", fn:count(fn:collection("transactions")))
      )
    },
    <options xmlns="xdmp:eval">
      <database>{xdmp:database("payments-content")}</database>
    </options>
  )
};

declare %private function dluhc:task-server-summary() as map:map* {
  let $task-server-statuses := for $host as xs:unsignedLong in xdmp:hosts()
    let $task-server-id := xdmp:host-status($host)//hs:task-server-id
    return xdmp:server-status($host, $task-server-id)
  return (
    dluhc:metric("task-server-host-max-queue-size", fn:max($task-server-statuses//ss:queue-size)),
    dluhc:metric("task-server-total-queue-size", fn:sum($task-server-statuses//ss:queue-size)),
    dluhc:metric("task-server-currently-processing", fn:count($task-server-statuses//ss:request-statuses/ss:request-status))
  )
};

"OUTPUT_JSON:" || xdmp:to-json((
  for $d in ("delta-content", "payments-content", "Security")
    return dluhc:metric($d || "-doc-count", dluhc:database-document-count($d)),
  dluhc:security-summary(),
  dluhc:payments-summary(),
  dluhc:task-server-summary()
))
