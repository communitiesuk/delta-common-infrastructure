yum install openldap-clients -y
sed -i 's/SELINUX=disabled/SELINUX=enforcing/g' /etc/selinux/config
chmod 754 /usr/bin/as

# Configure SSH banner:
echo "Legal Warning - Private System! This system and the data within it are private property. Access to the system is only available for authorised users and for authorised purposes. Unauthorised entry contravenes the Computer Misuse Act 1990 of the United Kingdom and may incur criminal penalties as well as damages." > /etc/ssh/banner
sed -i 's-#Banner none-Banner /etc/ssh/banner-g' /etc/ssh/sshd_config

sed -i 's/#*LogLevel [A-Za-z]*/LogLevel VERBOSE/' /etc/ssh/sshd_config
sed -i 's/#*MaxAuthTries [0-9]*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/#*MaxSessions [0-9]*/MaxSessions 2/' /etc/ssh/sshd_config
sed -i 's/#*AllowAgentForwarding [A-Za-z]*/AllowAgentForwarding no/' /etc/ssh/sshd_config
sed -i 's/#*X11Forwarding [A-Za-z]*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/#*TCPKeepAlive [A-Za-z]*/TCPKeepAlive no/' /etc/ssh/sshd_config
sed -i 's/#*Compression [A-Za-z]*/Compression no/' /etc/ssh/sshd_config
sed -i 's/#*ClientAliveCountMax [0-9]*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
sed -i 's/#*GSSAPIAuthentication [A-Za-z]*/GSSAPIAuthentication no/' /etc/ssh/sshd_config

/usr/sbin/sshd -t
systemctl restart sshd
