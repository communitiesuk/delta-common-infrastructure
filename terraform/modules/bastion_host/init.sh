#!/bin/bash

set -xe

yum -y update --security
yum -y install jq nc amazon-cloudwatch-agent iptables-services

mkdir /usr/bin/bastion
mkdir /var/log/bastion

systemctl enable iptables
systemctl start iptables
# Block non-root users from accessing the instance metadata service
iptables -A OUTPUT -m owner ! --uid-owner root -d 169.254.169.254 -j DROP
# Allow port 2345 for health checks
iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 2345 -j ACCEPT
service iptables save

# Fetch the host key from AWS Secrets Manager
aws secretsmanager get-secret-value --region ${region} --secret-id ${host_key_secret_id} --query SecretString --output text > /etc/ssh/ssh_host_ed25519_key
ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key

sed -i 's|HostKey /etc/ssh/ssh_host_ecdsa_key|#HostKey /etc/ssh/ssh_host_ecdsa_key|' /etc/ssh/sshd_config
sed -i 's|HostKey /etc/ssh/ssh_host_rsa_key|#HostKey /etc/ssh/ssh_host_rsa_key|' /etc/ssh/sshd_config
rm -f /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub
rm -f /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key.pub


# Check the SSH config is valid, otherwise sshd will not come back up
/usr/sbin/sshd -t
systemctl restart sshd

if [ ! -z "${cloudwatch_config_ssm_parameter}" ]; then
  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:${cloudwatch_config_ssm_parameter}"
fi

cat > /usr/bin/bastion/sync_users_with_s3 <<'EOF'
#!/usr/bin/env bash

set -xe

LOG_FILE="/var/log/bastion/changelog.log"
# Where we store etags of public keys for registered users
ETAGS_DIR=~/etags
# This file keeps track of which keys we've registered as users. Note: there are other system users,
# so this is specifically the users installed via S3 sync
REGISTERED_KEYS_FILE=~/registered_keys
# Where to dump the list of files in S3
S3_DATA_FILE=~/s3_data
AWS_BUCKET="${bucket_name}"
AWS_REGION="${region}"

aws s3api list-objects\
  --bucket $AWS_BUCKET\
  --region $AWS_REGION\
  --output json\
  --query 'Contents[?Size>`0`].{Key: Key, ETag: ETag}' > "$S3_DATA_FILE"

# Convert to lowercase and strip out the .pub at the end, if any
parse_username() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e "s/\.pub//g"
}

# Add/Update users with a key in S3
# We're encoding each entry in array to base64 so it fits onto a single line. We decode when we read the line.
for row in $(cat "$S3_DATA_FILE" | jq -r '.[] | @base64'); do
  _jq() {
    # Double dollar for Terraform escaping purposes
    echo $${row} | base64 --decode | jq -r $${1}
  }

  # Cut the .pub from the end of the public key name
  KEY=$(_jq '.Key')
  USER_NAME=$(parse_username "$KEY")
  ETAG=$(_jq '.ETag')

  # Check the username starts with a letter and only contains letters, numbers, dashes and underscores afterwards
  if [[ "$USER_NAME" =~ ^[a-z][-a-z0-9_]*$ ]]; then
    # Check whether the user already exists
    cut -d: -f1 /etc/passwd | grep -qx $USER_NAME  || error_code=$?
    if [ $error_code -eq 1 ]; then
      # See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/managing-users.html#create-user-account
      adduser $USER_NAME
      [ -d /home/$USER_NAME/.ssh ] || mkdir -m 700 /home/$USER_NAME/.ssh
      chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh
      echo "$KEY" >> "$REGISTERED_KEYS_FILE"
      echo "$(date --iso-8601='seconds'): Created user $USER_NAME" >> $LOG_FILE
    fi

    ETAG_FILE="$ETAGS_DIR/$USER_NAME"
    # If there is no etag, or key etag doesn't match, download from S3
    if [ ! -f "$ETAG_FILE" ] || [ "$(cat "$ETAG_FILE")" != "$ETAG" ]; then
      aws s3 cp s3://$AWS_BUCKET/$KEY /home/$USER_NAME/.ssh/authorized_keys --region $AWS_REGION
      if [ ! -f "$ETAG_FILE" ]; then
        mkdir -p "$ETAGS_DIR"
        touch "$ETAG_FILE"
      fi
      chmod 600 /home/$USER_NAME/.ssh/authorized_keys
      chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys
      # Update the etag
      echo $ETAG > "$ETAG_FILE"
      echo "$(date --iso-8601='seconds'): Updated public key for $USER_NAME from file ($KEY)" >> $LOG_FILE
    fi
  fi
done

# Remove users which no longer have a public key in S3
if [ -f "$REGISTERED_KEYS_FILE" ]; then
  # Convert JSON entries to simple list
  cat "$S3_DATA_FILE" | jq -r '.[].Key' > ~/s3_keys

  touch ~/tmp_registered_keys
  while read KEY; do
    if grep -Fxq "$KEY" ~/s3_keys; then
      # The key exists, so keep it
      echo "$KEY" >> ~/tmp_registered_keys
    else
      # The key is gone, so remove the user
      USER_NAME="$(parse_username "$KEY")"
      userdel -r -f $USER_NAME
      echo "$(date --iso-8601='seconds'): Deleted user $USER_NAME with key $KEY" >> $LOG_FILE
    fi
  done < "$REGISTERED_KEYS_FILE"
  # Replace the old list with the new list
  mv ~/tmp_registered_keys "$REGISTERED_KEYS_FILE"
fi
EOF

chmod 700 /usr/bin/bastion/sync_users_with_s3
PATH=$PATH:/sbin /usr/bin/bastion/sync_users_with_s3

# Update users every 5 minutes, check for security updates at 3AM
cat > ~/crontab << EOF
*/5 * * * * PATH=$PATH:/sbin /usr/bin/bastion/sync_users_with_s3
0 3 * * * yum -y update --security
@reboot bash -c "cat /dev/null | nohup nc -kl 2345 >/dev/null 2>&1 &"
EOF
crontab ~/crontab
rm ~/crontab

# Listen on port 2345 for healthcheck pings from the load balancer
bash -c "cat /dev/null | nohup nc -kl 2345 >/dev/null 2>&1 &"
