# Restoring data from Datamart

* On both environments
  * Disable scheduled tasks by running delta/ml-tier-app/src/queries/enable-scheduled-tasks.xqy with `$is-enabled` set to false
  * Disable relevant app servers using the enable-app-servers.xqy script similarly
  * Disable rebalancer using enable-rebalancer.xqy script similarly
* In the DLUHC environment manually disable any scheduled backups that might otherwise try to run while we're doing the restore
* Create backups of the delta-content, delta-testing-centre-content and payments-content databases from Datamart (stored in S3)
  * Include the Security db with the delta-content backup
  * You may have to create empty target folders for each DB first
* Restore the delta-content database in the DLUHC environment, along with the Security database
  * Forest topology changed -> true
  * Include auxiliary databases -> true
  * Or use the db-restore.xqy script
* Wait for that to complete
* Check the admin console (you will need to log in with Datamart admin credentials) and trigger the security DB upgrade
* Restore the payments-content database in the DLUHC environment, *without* the security database
* Restore the delta-testing-centre-content database, again without the security database

Afterwards:

* Run the three validation scripts in this folder against the original database and the restored one and check the output is the same.
* Create three admin users with passwords taken from AWS Secrets Manager:
  * admin, see "ml-admin-user-\<env>"
  * cpm-ml-admin, see "cpm-app-ml-password-\<env>"
  * jasperreports, see "\<env>-jaspersoft-ml-password"
* Update the post-migration-update-security.xqy query with the correct list of users to delete. Run it from the MarkLogic query console, targeting the Security database.
* Enable app servers using the script from above
* Run the Roxy deployment jobs from <https://github.com/communitiesuk/delta-marklogic-deploy> for both Delta and CPM.
* Delete the external security "datamart-eclaims-sec"
* Check the external securities "datamart-cpm-sec" and "datamart-sec" were configured correctly
* Re-enable scheduled tasks and rebalancer using the scripts from above
* Re-enable all scheduled backups
