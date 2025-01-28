#!/bin/bash -ex
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

yum update -y

# cat > ~/crontab << EOF
# 0 3 * * * yum -y update --security
# 0 5 * * 0 shutdown --reboot now
# EOF

# crontab ~/crontab
# rm ~/crontab

# We block external NTP requests, stop noise at the firewall
# Will still use the AWS local one (169.254.169.123)
rm -f /etc/chrony.d/ntp-pool.sources

# Install docker
yum install -y docker
service docker start
usermod -a -G docker ec2-user

yum install -y amazon-cloudwatch-agent jq git gcc ruby ruby-devel rubygems

gem install rexml

user_name=ec2-user

${install_runner}

${start_runner}
