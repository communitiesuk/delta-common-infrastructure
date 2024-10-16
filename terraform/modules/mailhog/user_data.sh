#!/bin/bash

set -exuo pipefail

# We block external NTP requests, stop noise at the firewall
# Will still use the AWS local one (169.254.169.123)
rm -f /etc/chrony.d/ntp-pool.sources

# Daily job to delete stored emails older than 3 days
echo "0 2 * * * find /mailhog/mail/ -type f -mtime +3 -execdir rm -- '{}' \;" | crontab -

yum update
yum install golang -y

go version

mkdir /mailhog
useradd -d /mailhog -r -U mailhog
chown mailhog:mailhog /mailhog
sudo -u mailhog mkdir -p /mailhog/mail

cd /mailhog
sudo -u mailhog go install github.com/mailhog/MailHog@latest

aws secretsmanager get-secret-value --region ${region} --secret-id ${auth_file_secret_id} --query SecretString --output text > /mailhog/auth
chown mailhog:mailhog /mailhog/auth

cat <<'EOF' | tee /etc/systemd/system/mailhog.service >/dev/null
[Unit]
Description=Mailhog
After=syslog.target network.target

[Service]
User=mailhog
Group=mailhog

# Mailhog sends email from its hostname, see https://github.com/mailhog/MailHog-Server/blob/master/api/v1.go#L335
Environment=MH_HOSTNAME=datacollection.dluhc-dev.uk
Environment=MH_MAILDIR_PATH=/mailhog/mail
Environment=MH_STORAGE=maildir
Environment=MH_AUTH_FILE=/mailhog/auth
Environment=MH_OUTGOING_SMTP=/mailhog/smtp
ExecStart=/mailhog/go/bin/MailHog

[Install]
WantedBy=multi-user.target
EOF

# Port 465 wasn't working so using 25, even though EC2 may block that in future
cat <<'EOF' | tee /mailhog/smtp >/dev/null
{
    "ses_test": {
        "name": "ses_test",
        "host": "email-smtp.eu-west-1.amazonaws.com",
        "port": "25",
        "email": "mailhog@datacollection.dluhc-dev.uk",
        "username": "${smtp_username}",
        "password": "${smtp_password}",
        "mechanism": "PLAIN"
    }
}
EOF
chown mailhog:mailhog /mailhog/smtp

systemctl daemon-reload
systemctl enable mailhog --now

echo "Done"
