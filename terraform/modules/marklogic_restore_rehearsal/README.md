# MarkLogic Restore Rehearsal

This module is to spin up a copy of the actual MarkLogic cluster to run alongside it, in order to complete a practice run of restoring the database from backup without interrupting the actual cluster.

It relies on resources in the networking module. 

See the Run Book on confluence for more detail. 

Use it similarly to the main "marklogic" module, only changing the subnet to the test cluster's own subnet and removing unused variables.
