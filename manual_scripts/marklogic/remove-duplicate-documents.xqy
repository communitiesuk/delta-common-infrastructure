xquery version "1.0-ml";

(:
Duplicate doc deletion on production 2023-03-06
Used to fix errors rebalancing
See https://help.marklogic.com/knowledgebase/article/View/understanding-xdmp-dbdupuri-exceptions-how-they-can-occur-and-how-to-prevent-them
:)

let $dupes := (
<dupe>
  <uri>/datasets/h-clic-2021-2022/h-clic-2021-2022-jan-mar/submissions/cfa3e5a92ae697fbd80045cd5a61f6f1/E09000025_000000030363-validation/35472f4270b8afd73e2a1af18a312da04513dcef.xml</uri>
  <forest1>delta-content-003-2</forest1>
  <forest2>delta-content-002-3</forest2>
</dupe>,
<dupe>
  <uri>/datasets/h-clic-2021-2022/h-clic-2021-2022-jul-sep/submissions/4b4e335b58e8479c8d069868a6d12335/E09000019_000000153889-validation/043f458b7ca4c00e522326715db6d01b09b6f3c8.xml</uri>
  <forest1>delta-content-003-8</forest1>
  <forest2>delta-content-001-5</forest2>
</dupe>,
<dupe>
  <uri>/datasets/h-clic-2020-2021/h-clic-2020-2021-jan-mar/submissions/7c8b3369377406e94dfe9a01e9d1d3cb/E09000020_000001266304-validation/5677d81a09c918a6b97adf08585337431a4184b1.xml</uri>
  <forest1>delta-content-002-2</forest1>
  <forest2>delta-content-003-3</forest2>
</dupe>,
<dupe>
  <uri>/datasets/h-clic-error-checker/h-clic-error-checker-april2021/submissions/66262080014dbeca1b1795b61bb2cb4f/E09000026_000030040367-validation.xml</uri>
  <forest1>delta-content-003-4</forest1>
  <forest2>delta-content-002-1</forest2>
</dupe>
)

for $dupe in $dupes
  let $doc := $dupe/uri/text()

  let $forest-a-name := $dupe/forest1/text()
  let $forest-b-name := $dupe/forest2/text()

  let $query :=
    'xquery version "1.0-ml";
    declare variable $URI as xs:string external;
    fn:doc($URI)'

  let $options-a := <options xmlns="xdmp:eval"><database>{xdmp:forest($forest-a-name)}</database></options>
  let $options-b := <options xmlns="xdmp:eval"><database>{xdmp:forest($forest-b-name)}</database></options>

  let $results-a := xdmp:eval($query,(xs:QName("URI"),$doc),$options-a)
  let $results-b := xdmp:eval($query,(xs:QName("URI"),$doc),$options-b)

  return if (fn:not(xdmp:hash64(xdmp:quote($results-a)) = xdmp:hash64(xdmp:quote($results-b)))) then
    fn:error(xs:QName("ERROR"), "Forest doc mismatch " || $doc)
  else
    let $query :=
      'xquery version "1.0-ml";
      declare variable $URI as xs:string external;
      xdmp:document-delete($URI)'

    let $options := <options xmlns="xdmp:eval"><database>{xdmp:forest($forest-a-name)}</database></options>
    return xdmp:eval($query,(xs:QName("URI"),$doc),$options)
