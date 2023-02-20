xquery version "1.0-ml";

declare namespace grant = "http://www.gov.uk/dclg/modules/cpm/grants";
declare namespace transaction = "urn:dclg.gov.uk:cpm:transactions";
declare namespace payment = "http://www.gov.uk/dclg/modules/cpm/payments";

"Current database: " || xdmp:database-name(xdmp:database()),

let $grant-hashes := for $grant in fn:collection("grant")
order by $grant/grant:grant/grant:grant-code
return xdmp:hash64(xdmp:quote($grant))

return ("Number of Grants: " || fn:count($grant-hashes), "Grants hash: " || xdmp:hash64(xdmp:quote($grant-hashes))),

let $transaction-hashes := for $transaction in fn:collection("transactions")
order by $transaction/transaction:transaction/transaction:id
return xdmp:hash64(xdmp:quote($transaction))

return ("Number of Transactions: " || fn:count($transaction-hashes), "Transactions hash: " || xdmp:hash64(xdmp:quote($transaction-hashes))),

(: Takes too long to loop over them all :)
"Count of payments: " || fn:count(fn:collection("payment"))
