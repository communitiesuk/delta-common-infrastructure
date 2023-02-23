xquery version "1.0-ml";

(:
 : Script to summarise the forests for the databases we're restoring.
 : Intended to be run before and after the restore and diffed to make sure we haven't missed a forest or messed up the mapping.
 :)

declare namespace forest = "http://marklogic.com/xdmp/status/forest";
declare namespace dluhc = "http://levellingup.gov.uk";

declare %private function dluhc:forest-summary($database-name as xs:string) as xs:string* {
  let $database := xdmp:database($database-name)
  let $forest-ids := xdmp:database-forests($database)
  for $forest-id in $forest-ids
    let $forest-counts := xdmp:forest-counts($forest-id, ("document-count"))
    order by $forest-counts/forest:forest-name/text()
  return $forest-counts/forest:forest-name/text() || " - " || $forest-counts/forest:document-count/text() || " documents"
};

"Summary for delta-content",
dluhc:forest-summary("delta-content"),
"Summary for payments-content",
dluhc:forest-summary("payments-content"),
"Summary for delta-testing-centre-content",
dluhc:forest-summary("delta-testing-centre-content"),
"Summary for Security",
(: Note the number of documents will be slightly different after the version upgrade :)
dluhc:forest-summary("Security"),

xdmp:invoke-function(function() {
    "Number of users " || fn:count(//sec:user),
    "Number of roles " || fn:count(//sec:role)
  }, 
    <options xmlns="xdmp:eval">
      <database>{xdmp:security-database()}</database>
    </options>
)
