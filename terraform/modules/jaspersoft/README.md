# JasperReports Server

The password for the "jasperreports" ldap user must be in a secret named `jasperserver-ldap-bind-password-${var.environment}` using the AWS managed KMS key.

Requires S3 bucket (var.jaspersoft_binaries_s3_bucket) in the current AWS account with JasperReports Server binaries in.

```sh
bucket_name=dluhc-jaspersoft-bin-prod
aws s3api create-bucket --bucket $bucket_name --acl private --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket $bucket_name --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $bucket_name --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
```

Once you've created the instance login to Jaspersoft and change the password for the default users (e.g. jasperadmin/jasperadmin).

## Creating the WAR file

We've combined Jasper Reports Community edition 7.8.0, the 7.8.1 Service Pack, the 2022-04-15 cumulative hotfix and web services plugin into one zip:

```sh
#!/bin/bash -ex
# Extract archives
unzip -q TIB_js-jrs-cp_7.8.0_bin.zip
unzip -q TIB_js-jrs_cp_7.8.1_sp.zip -d js-sp-7.8.1
unzip -q hotfix_jrspro7.8.1_cumulative_20220415_1823.zip -d js-hotfix-7.8.1
unzip -q jaspersoft_webserviceds_v1.5.zip -d webservices
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

## Web services plugin
sed -i 's/queryLanguagesPro/queryLanguagesCe/' webservices/JRS/WEB-INF/applicationContext-WebServiceDataSource.xml
sed -i 's/jasperQL/WebServiceQuery/' webservices/JRS/WEB-INF/applicationContext-remote-services.xml
cp -r webservices/JRS/WEB-INF/* jasperreports-server-cp-7.8.0-bin/jasperserver/WEB-INF/

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

## Updating Tomcat

As root:

```sh
# cd into the Tomcat folder
cd /opt/tomcat
# Note the current version, look for the target of the latest symlink
ls -l
# Stop tomcat
systemctl stop tomcat
# Delete symlink
rm latest

# Install new version
TOMCAT_VERSION=9.0.70
wget "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" -P /tmp
sudo -u tomcat tar -xf /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat/
rm -f /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz

# Recreate symlink
sudo -u tomcat ln -s /opt/tomcat/apache-tomcat-${TOMCAT_VERSION} /opt/tomcat/latest
# Restart tomcat
systemctl start tomcat
# Tail the logs while it starts, takes about a minute
# Fine to ignore OperationNotSupportedException: Context is read only
tail -f base/logs/catalina.out
```

Check it's working again. If something goes wrong try deleting base/work and base/temp and restarting Tomcat again.

To roll back: stop Tomcat again, repoint the `latest/` symlink at the previous version, then restart Tomcat.

## Migration

To migrate between servers:

* From the old server, export a zip file via: Manage -> Server Settings -> Export. Choose to export everything except users/roles
* Import that file on the new server via Manage -> Server Settings -> Import.
* Add a file at root/DELTA/Sub Reports/treasury-report-common.jrxml (file is in the Delta repo). Set the resource ID to "TR_Common.jrxml"
* Edit the data source "ML POST" so that it has the correct URL, port and credentials for connection to MarkLogic:
  * `http://marklogic.vpc.local:8143/?user=jasperreports`
  * Username = `jasperreports`, password in Secrets Manager. Needs to be created on the MarkLogic server
* On staging, edit the queries in treasury-report.jrxml and treasury-report-common.jrxml to use the line labelled "for staging". Otherwise the report gets stuck in an infinite loop, fills up the disk and crashes the server. On test, maybe best to avoid the treasury report.

## From on server postgres to RDS

We have moved the database from on the instance to RDS by dumping and restoring the database.
This has been done on all environments, but is documented here in case we need to move the database around in the future.

```sh
su postgres -c "pg_dump -d jasperserver --format custom --create --no-owner" > db_dump

psql --host "jaspersoft-db.vpc.local" --username jaspersoft --password -d postgres -c 'CREATE USER postgres IN GROUP rds_superuser;'
pg_restore "./db_dump" --create --clean --dbname postgres --host "jaspersoft-db.vpc.local" --username jaspersoft --password --exit-on-error
psql --host "jaspersoft-db.vpc.local" --username jaspersoft --password -d postgres -c 'ALTER DATABASE jasperserver OWNER TO jaspersoft;'
```
