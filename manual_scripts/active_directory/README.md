
### Set up minimal data

After setting up the Active Directory server with Terraform, installing tools as described in the module's README.md, you should be able to use the `activedirectory` PowerShell module on the management server. Copy the "add-..." scripts and csv files from here to set up the necessary groups/users for Delta/CPM.

### Set password policy

Similarly, there's a script for setting the password policies for Delta users and system users

### Management Server setup

There are some security settings we've enabled on the management server, as recommended during the audit 02/2023, that should be applied to Windows machines. You can enable these via the `Local Security Policy` application, go to `Local Policies` -> `Security Options`

* Guest account disabled and renamed
* Interactive Login: Do not display last signed-in -> Enabled
* Interactive Login: Message text for users attempting to log on -> "Legal Warning - Private System!"
* Interactive Login: Message title for users attempting to log on (both are required) -> "This system and the data within it are private property. Access to the system is only available for authorised users and for authorised purposes. Unauthorised entry contravenes the Computer Misuse Act 1990 of the United Kingdom and may incur criminal penalties as well as damages."
* Microsoft Network Client: Digitally sign communication (always) -> Enabled
* Network Access: Do not allow anonymous enumeration of SAM accounts and shares -> Enabled
* Network Security: LAN Manager authentication level -> Send NTLMv2 response only and refuse LM
* User Account Control: Use Admin Approval Mode for the built-in Administrator account -> Enabled
