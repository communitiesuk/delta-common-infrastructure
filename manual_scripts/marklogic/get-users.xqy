xquery version "1.0-ml";

(: Run this against the Security DB :)

import module namespace sec="http://marklogic.com/xdmp/security" at 
    "/MarkLogic/security.xqy";

for $user in //sec:user
return $user/sec:user-name/text()