#!/bin/bash

for db in Meters App-Services Documents Extensions Fab
do
    echo "Updating ${db} database"
    curl -X PUT "http://localhost:8002/manage/v2/databases/${db}/properties" \
      --digest -u admin:admin -d "@${db}.xml" -H "Content-Type: application/xml"
done
