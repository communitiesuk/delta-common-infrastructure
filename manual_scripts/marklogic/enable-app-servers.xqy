xquery version "1.0-ml";

import module namespace admin =
    "http://marklogic.com/xdmp/admin" at
    "/MarkLogic/admin.xqy";

declare variable $config as element(configuration) := admin:get-configuration();
declare variable $group-id as xs:unsignedLong := xdmp:group();
(: delta-deploy is called delta-dluhc-deploy on our cluster :)
declare variable $app-server-ids := for $app-server-name in ("delta", "delta-api", "delta-deploy", "delta-testing-centre", "payments", "delta-xcc", "payments-xcc")
    return admin:appserver-get-id($config, $group-id, $app-server-name);
declare variable $is-enabled as xs:boolean := fn:true();

for $app-server-id in $app-server-ids
return
    admin:save-configuration-without-restart(
        admin:appserver-set-enabled($config, $app-server-id, $is-enabled)
    )
