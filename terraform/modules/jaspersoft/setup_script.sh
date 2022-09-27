#!/bin/bash

set -exuo pipefail

export TOMCAT_VERSION=9.0.65

# Let the instance finish booting

sleep 5

# Based on the JasperReports Server CP Install Guide for 7.8

# Setup

apt update && apt upgrade -y
apt install wget awscli lsb-release gnupg unzip -y

# Install Java

apt install openjdk-11-jdk -y

# Install Tomcat

rm -rf /opt/tomcat/base
rm -rf /opt/tomcat/apache-tomcat-$${TOMCAT_VERSION}
id -u tomcat &>/dev/null || useradd -m -U -d /opt/tomcat tomcat
sudo -u tomcat mkdir -p /opt/tomcat/base
wget "https://archive.apache.org/dist/tomcat/tomcat-9/v$${TOMCAT_VERSION}/bin/apache-tomcat-$${TOMCAT_VERSION}.tar.gz" -P /tmp
sudo -u tomcat tar -xf /tmp/apache-tomcat-$${TOMCAT_VERSION}.tar.gz -C /opt/tomcat/
rm -f /tmp/apache-tomcat-$${TOMCAT_VERSION}.tar.gz
rm -f /opt/tomcat/latest
sudo -u tomcat ln -s /opt/tomcat/apache-tomcat-$${TOMCAT_VERSION} /opt/tomcat/latest

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" > /etc/profile.d/java-tomcat-vars.sh
echo "export CATALINA_BASE=/opt/tomcat/base" >> /etc/profile.d/java-tomcat-vars.sh
echo "export CATALINA_HOME=/opt/tomcat/latest" >> /etc/profile.d/java-tomcat-vars.sh
source /etc/profile.d/java-tomcat-vars.sh

sudo -u tomcat cp -r $${CATALINA_HOME}/conf/ $${CATALINA_BASE}/conf/
sudo -u tomcat mkdir $${CATALINA_BASE}/webapps/
sudo -u tomcat mkdir $${CATALINA_BASE}/logs
sudo -u tomcat mkdir $${CATALINA_BASE}/temp
sudo -u tomcat mkdir $${CATALINA_BASE}/work
sudo -u tomcat mkdir $${CATALINA_BASE}/lib

# Setup a simple ROOT app that redirects to /jasperserver
sudo -u tomcat mkdir $${CATALINA_BASE}/webapps/ROOT
sudo -u tomcat mkdir $${CATALINA_BASE}/webapps/ROOT/WEB-INF
aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/root_index.jsp $${CATALINA_BASE}/webapps/ROOT/index.jsp
aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/root_web.xml $${CATALINA_BASE}/webapps/ROOT/WEB-INF/web.xml

aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/tomcat.service /etc/systemd/system/tomcat.service
systemctl daemon-reload
systemctl enable tomcat

# Install Postgresql 11

echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
DEBIAN_FRONTEND=noninteractive apt -y install postgresql-11
pg_ctlcluster 11 main start
su postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'postgres';\""

# Download JasperSoft files

su tomcat -c "aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/TIB_js-jrs-cp_7.8.0_bin.zip /tmp"
su tomcat -c "aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/TIB_js-jrs_cp_7.8.1_sp.zip /tmp"
aws s3 cp s3://${JASPERSOFT_INSTALL_S3_BUCKET}/default_master.properties /tmp

# We may also need to install Chrome, I haven't done this
# > You need to install and configure Chrome/Chromium to export the reports to PDF and other output formats.

# Unzip and apply service pack

rm -rf /opt/tomcat/jaspersoft_install /opt/tomcat/jaspersoft_sp

sudo -u tomcat unzip /tmp/TIB_js-jrs-cp_7.8.0_bin.zip -d /opt/tomcat/jaspersoft_install
sudo -u tomcat unzip /tmp/TIB_js-jrs_cp_7.8.1_sp.zip -d /opt/tomcat/jaspersoft_sp
sudo -u tomcat unzip /opt/tomcat/jaspersoft_sp/js-install.zip -d /opt/tomcat/jaspersoft_sp/js-install
sudo -u tomcat rsync -a /opt/tomcat/jaspersoft_sp/js-install/buildomatic/ /opt/tomcat/jaspersoft_install/jasperreports-server-cp-7.8.0-bin/buildomatic/

cd /opt/tomcat/jaspersoft_install/jasperreports-server-cp-7.8.0-bin/buildomatic
cp /tmp/default_master.properties ./default_master.properties
chown tomcat ./default_master.properties

# Run install
su tomcat -c "./js-install-ce.sh minimal"

# Fix for invalid CSRF header name, ALB will drop headers with underscores in
sed -i 's/^org.owasp.csrfguard.TokenName=OWASP_CSRFTOKEN/org.owasp.csrfguard.TokenName=OWASPCSRFTOKEN/' /opt/tomcat/base/webapps/jasperserver/WEB-INF/csrf/jrs.csrfguard.properties

sudo -u tomcat cp /opt/tomcat/jaspersoft_install/jasperreports-server-cp-7.8.0-bin/buildomatic/conf_source/db/postgresql/jdbc/postgresql-42.2.5.jar /opt/tomcat/base/lib/

systemctl start tomcat

echo "Done"

# TODO: LDAP config
