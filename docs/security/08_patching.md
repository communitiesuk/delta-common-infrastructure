# Patching

Patching of OS-managed packages is automated using cron or AWS Systems Manager Maintenance Windows.

The Active Directory management and certificate authority Windows EC2 instances are patched weekly using the AWS default Windows patch baseline. The management instance is patched before the certificate authority instance and each host is rebooted when patch installation requires it. AWS patches the AWS Managed Microsoft AD domain controllers as part of the managed service.

Other components (vendor application versions, Tomcat etc.) are patched manually on a schedule documented on Confluence as part of the Run Book: <https://mhclgdigital.atlassian.net/wiki/spaces/DT/pages/3375127/Patching>
