xquery version "3.0";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace map = "http://marklogic.com/xdmp/map";

let $content-database-id := admin:database-get-id(
       admin:get-configuration(),
       "delta-content"
    )
let $schemas-database-id := admin:database-get-id(
       admin:get-configuration(),
       "delta-schemas"
    )
let $triggers-database-id := admin:database-get-id(
       admin:get-configuration(),
       "delta-triggers"
    )
let $security-database-id := admin:database-get-id(
       admin:get-configuration(),
       "Security"
    )
let $forest-ids := (
    xdmp:database-forests($content-database-id, fn:true()),
    xdmp:database-forests($schemas-database-id, fn:true()),
    xdmp:database-forests($triggers-database-id, fn:true()),
    xdmp:database-forests($security-database-id, fn:true())
)
let $map := map:new((
  map:entry("delta-content-001-1", ("delta-content-001-1")),
  map:entry("delta-content-001-2", ("delta-content-001-2")),
  map:entry("delta-content-001-3", ("delta-content-001-3")),
  map:entry("delta-content-001-4", ("delta-content-001-4")),
  map:entry("delta-content-001-5", ("delta-content-004-1")),
  map:entry("delta-content-001-6", ("delta-content-004-2")),
  map:entry("delta-content-001-7", ("delta-content-004-3")),
  map:entry("delta-content-001-8", ("delta-content-004-4")),
  map:entry("delta-content-002-1", ("delta-content-002-1")),
  map:entry("delta-content-002-2", ("delta-content-002-2")),
  map:entry("delta-content-002-3", ("delta-content-002-3")),
  map:entry("delta-content-002-4", ("delta-content-002-4")),
  map:entry("delta-content-002-5", ("delta-content-005-1")),
  map:entry("delta-content-002-6", ("delta-content-005-2")),
  map:entry("delta-content-002-7", ("delta-content-005-3")),
  map:entry("delta-content-002-8", ("delta-content-005-4")),
  map:entry("delta-content-003-1", ("delta-content-003-1")),
  map:entry("delta-content-003-2", ("delta-content-003-2")),
  map:entry("delta-content-003-3", ("delta-content-003-3")),
  map:entry("delta-content-003-4", ("delta-content-003-4")),
  map:entry("delta-content-003-5", ("delta-content-006-1")),
  map:entry("delta-content-003-6", ("delta-content-006-2")),
  map:entry("delta-content-003-7", ("delta-content-006-3")),
  map:entry("delta-content-003-8", ("delta-content-006-4")),
  map:entry("delta-content-001-1-rep1-on-002", ("delta-content-001-1-rep1-on-002")),
  map:entry("delta-content-001-2-rep1-on-002", ("delta-content-001-2-rep1-on-002")),
  map:entry("delta-content-001-3-rep1-on-002", ("delta-content-001-3-rep1-on-002")),
  map:entry("delta-content-001-4-rep1-on-002", ("delta-content-001-4-rep1-on-002")),
  map:entry("delta-content-001-5-rep1-on-002", ("delta-content-004-1-rep1-on-005")),
  map:entry("delta-content-001-6-rep1-on-002", ("delta-content-004-2-rep1-on-005")),
  map:entry("delta-content-001-7-rep1-on-002", ("delta-content-004-3-rep1-on-005")),
  map:entry("delta-content-001-8-rep1-on-002", ("delta-content-004-4-rep1-on-005")),
  map:entry("delta-content-002-1-rep1-on-003", ("delta-content-002-1-rep1-on-003")),
  map:entry("delta-content-002-2-rep1-on-003", ("delta-content-002-2-rep1-on-003")),
  map:entry("delta-content-002-3-rep1-on-003", ("delta-content-002-3-rep1-on-003")),
  map:entry("delta-content-002-4-rep1-on-003", ("delta-content-002-4-rep1-on-003")),
  map:entry("delta-content-002-5-rep1-on-003", ("delta-content-005-1-rep1-on-006")),
  map:entry("delta-content-002-6-rep1-on-003", ("delta-content-005-2-rep1-on-006")),
  map:entry("delta-content-002-7-rep1-on-003", ("delta-content-005-3-rep1-on-006")),
  map:entry("delta-content-002-8-rep1-on-003", ("delta-content-005-4-rep1-on-006")),
  map:entry("delta-content-003-1-rep1-on-001", ("delta-content-003-1-rep1-on-004")),
  map:entry("delta-content-003-2-rep1-on-001", ("delta-content-003-2-rep1-on-004")),
  map:entry("delta-content-003-3-rep1-on-001", ("delta-content-003-3-rep1-on-004")),
  map:entry("delta-content-003-4-rep1-on-001", ("delta-content-003-4-rep1-on-004")),
  map:entry("delta-content-003-5-rep1-on-001", ("delta-content-006-1-rep1-on-001")),
  map:entry("delta-content-003-6-rep1-on-001", ("delta-content-006-2-rep1-on-001")),
  map:entry("delta-content-003-7-rep1-on-001", ("delta-content-006-3-rep1-on-001")),
  map:entry("delta-content-003-8-rep1-on-001", ("delta-content-006-4-rep1-on-001")),
  map:entry("delta-schemas", ("delta-schemas")),
  map:entry("delta-triggers", ("delta-triggers")),
  map:entry("Security", ("Security")),
  map:entry("Security-rep1-on-002", ("security-replica-1"))
))
return xdmp:database-restore(
    $forest-ids,
    "s3://datamart-ml-backups-production/delta-content/20230215-0300016866090/",
    (),
    fn:false(),
    (),
    fn:false(),
    (),
    (),
    $map
)