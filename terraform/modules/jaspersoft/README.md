# JasperReports Server

Requires S3 bucket (var.jaspersoft_binaries_s3_bucket) in the current AWS account with JasperReports Server binaries in.

```sh
aws s3api create-bucket --bucket dluhc-jaspersoft-bin --acl private --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket dluhc-jaspersoft-bin --versioning-configuration Status=Enabled
```

We've combined Jasper Reports Community edition 7.8.0, the 7.8.1 Service Pack and 2022-04-15 cumulative hotfix into one zip:

```sh
#!/bin/bash -ex
# Extract archives
unzip -q TIB_js-jrs-cp_7.8.0_bin.zip
unzip -q TIB_js-jrs_cp_7.8.1_sp.zip -d js-sp-7.8.1
unzip -q hotfix_jrspro7.8.1_cumulative_20220415_1823.zip -d js-hotfix-7.8.1
# Update postgres driver
rm jasperreports-server-cp-7.8.0-bin/buildomatic/conf_source/db/postgresql/jdbc/postgresql-42.2.5.jar
wget -O jasperreports-server-cp-7.8.0-bin/buildomatic/conf_source/db/postgresql/jdbc/postgresql-42.5.0.jar "https://jdbc.postgresql.org/download/postgresql-42.5.0.jar"

# Patch install tool
## Service pack
unzip -q js-sp-7.8.1/js-install.zip -d sp-js-install
rsync -a sp-js-install/buildomatic/ jasperreports-server-cp-7.8.0-bin/buildomatic/
## Hotfix
unzip -q js-hotfix-7.8.1/js-install.zip -d hotfix-js-install
rm hotfix-js-install/buildomatic/conf_source/iePro/applicationContext-adhoc.xml
rm hotfix-js-install/buildomatic/conf_source/iePro/applicationContext-pro-remote-services.xml
mv hotfix-js-install/buildomatic/conf_source/iePro hotfix-js-install/buildomatic/conf_source/ieCe
cd jasperreports-server-cp-7.8.0-bin/buildomatic/
rm conf_source/ieCe/lib/log4j-1.2-api-2.13.3.jar conf_source/ieCe/lib/log4j-api-2.13.3.jar conf_source/ieCe/lib/log4j-core-2.13.3.jar conf_source/ieCe/lib/log4j-jcl-2.13.3.jar conf_source/ieCe/lib/log4j-jul-2.13.3.jar conf_source/ieCe/lib/log4j-slf4j-impl-2.13.3.jar lib/log4j-1.2-api-2.13.3.jar lib/log4j-api-2.13.3.jar lib/log4j-core-2.13.3.jar lib/log4j-jcl-2.13.3.jar
cd ../..
rsync -a hotfix-js-install/buildomatic/ jasperreports-server-cp-7.8.0-bin/buildomatic/

# Patch WAR
## Service pack
unzip -q jasperreports-server-cp-7.8.0-bin/jasperserver.war -d jasperreports-server-cp-7.8.0-bin/jasperserver
unzip -q js-sp-7.8.1/jasperserver.zip -d war-sp
rsync -a war-sp/ jasperreports-server-cp-7.8.0-bin/jasperserver/

## Hotfix
unzip -q js-hotfix-7.8.1/jasperserver-pro.zip -d war-hotfix
cd war-hotfix/WEB-INF
### Remove jasper pro specific files
rm -r applicationContext-adhoc.xml applicationContext-pro-remote-services.xml applicationContext-security-pro-web.xml web.xml jsp/
cd ../../jasperreports-server-cp-7.8.0-bin/jasperserver/WEB-INF/lib
### Delete old log4j jars
rm log4j-1.2-api-2.13.3.jar log4j-api-2.13.3.jar log4j-core-2.13.3.jar log4j-jcl-2.13.3.jar log4j-jul-2.13.3.jar log4j-slf4j-impl-2.13.3.jar log4j-web-2.13.3.jar
cd ../../../..
rsync -a war-hotfix/WEB-INF/ jasperreports-server-cp-7.8.0-bin/jasperserver/WEB-INF/

## Recreate WAR
rm jasperreports-server-cp-7.8.0-bin/jasperserver.war
cd jasperreports-server-cp-7.8.0-bin/jasperserver/
zip -q ../jasperserver.war -r *
cd ..
rm -r jasperserver

# Zip back up
zip -q ../js-7.8.1_hotfixed_2022-04-15.zip -r *
cd ..
# Upload
aws s3 cp js-7.8.1_hotfixed_2022-04-15.zip s3://dluhc-jaspersoft-bin
```
