Restoring a database from MarkLogic
* Create backups of the delta-content and payments-content databases from Datamart (stored in S3)
* Restore the delta-content database in the DLUHC environment, along with the Security database
* Restore the payments-content database in the DLUHC environment, *without* the security database

Afterwards:

* Update the post-migration-update-security.xqy query with the correct list of users to delete. Run it from the MarkLogic query console, targeting the Security database.
* Update the admin user to use the relevant password stored in AWS secrets manager
* Run the Roxy deployment jobs from https://github.com/communitiesuk/delta-marklogic-deploy for both Delta and CPM.