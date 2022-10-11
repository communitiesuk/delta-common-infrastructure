
### Set up minimal data

After setting up the Active Directory server with Terraform, installing tools as described in the module's README.md, you should be able to use the `activedirectory` PowerShell module on the management server. Copy the "add-..." scripts and csv files from here to set up the necessary groups/users for Delta/CPM.

### Set password policy

Similarly, there's a script for setting the password policy to match Datamart's.
