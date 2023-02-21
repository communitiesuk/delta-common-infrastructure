xquery version "1.0-ml";

import module namespace admin =
    "http://marklogic.com/xdmp/admin" at
    "/MarkLogic/admin.xqy";

declare variable $config as element(configuration) := admin:get-configuration();
declare variable $db-ids := for $db-name in ("delta-content", "delta-testing-centre-content", "payments-content", "Security")
    return admin:database-get-id($config, $db-name);
declare variable $is-enabled as xs:boolean := fn:true();

for $db-id in $db-ids
return
    admin:save-configuration-without-restart(
        admin:database-set-rebalancer-enable($config, $db-id, $is-enabled)
    )
