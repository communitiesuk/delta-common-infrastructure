#!/bin/bash -e
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

yum update -y

cat > ~/crontab << EOF
0 3 * * * yum -y update --security
0 5 * * 0 shutdown --reboot now
EOF

crontab ~/crontab
rm ~/crontab

# Install docker
amazon-linux-extras install docker
service docker start
usermod -a -G docker ec2-user

yum install -y amazon-cloudwatch-agent curl jq git ruby

user_name=ec2-user

${install_runner}

${start_runner}
