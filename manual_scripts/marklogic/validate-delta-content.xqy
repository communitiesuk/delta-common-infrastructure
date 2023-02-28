xquery version "1.0-ml";

(:
 : Script to summarise the delta-content database.
 : Intended to be run before and after the restore and diffed.
 : Looping over every document would take far too long so we just check a few collections.
 : It should catch issues like a missed forest or badly corrupted data.
 : Takes about 20 seconds to run on production.
 :)

declare namespace organisation = "http://www.gov.uk/dclg/delta/organisation";
declare namespace dataset = "http://www.gov.uk/dclg/delta/dataset";
declare namespace instance = "http://www.gov.uk/dclg/delta/instance";

"Current database: " || xdmp:database-name(xdmp:database()),

let $org-hashes := for $org in fn:collection("/organisation")
order by $org/organisation:organisation/organisation:code
return xdmp:hash64(xdmp:quote($org))

return ("Number of Organisations: " || fn:count($org-hashes), "Organisations hash: " || xdmp:hash64(xdmp:quote($org-hashes))),

let $dataset-hashes := for $dataset in fn:collection("/dataset")
order by fn:document-uri($dataset)
return xdmp:hash64(xdmp:quote($dataset))

return ("Number of Datasets: " || fn:count($dataset-hashes), "Datasets hash: " || xdmp:hash64(xdmp:quote($dataset-hashes))),

let $instance-hashes := for $instance in fn:collection("/instance")
order by $instance/instance:instance/instance:instance-id
return xdmp:hash64(xdmp:quote($instance))

return ("Number of Instances: " || fn:count($instance-hashes), "Instances hash: " || xdmp:hash64(xdmp:quote($instance-hashes))),

let $document-hashes := for $document in fn:collection("/document")
order by fn:document-uri($document)
return xdmp:hash64(xdmp:quote($document))

return ("Number of Delta Documents: " || fn:count($document-hashes), "Documents hash: " || xdmp:hash64(xdmp:quote($document-hashes)))
