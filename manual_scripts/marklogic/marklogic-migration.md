Restoring a database from MarkLogic
* Create backups of the delta-content, delta-testing-centre-content and payments-content databases from Datamart (stored in S3)
  * You may have to create empty target folders for each DB first.
* Restore the delta-content database in the DLUHC environment, along with the Security database
  * Forest topology changed -> true
  * Include auxiliary databases -> true
  * Or use the db-restore.xqy script 
* Wait for that to complete
* Check the admin console (you will need to log in with Datamart admin credentials) and trigger the security DB upgrade
* Restore the payments-content database in the DLUHC environment, *without* the security database
* Restore the delta-testing-centre-content database, again without the security database

Afterwards:

* Create three admin users with passwords taken from AWS Secrets Manager:
  * admin, see "ml-admin-user-<env>"
  * cpm-ml-admin, see "cpm-app-ml-password-<env>"
  * jasperreports, see "<env>-jaspersoft-ml-password"
* Update the post-migration-update-security.xqy query with the correct list of users to delete. Run it from the MarkLogic query console, targeting the Security database.
* Run the Roxy deployment jobs from https://github.com/communitiesuk/delta-marklogic-deploy for both Delta and CPM.
* Delete the external security "datamart-eclaims-sec"
* Check the external securities "datamart-cpm-sec" and "datamart-sec" are configured correctly