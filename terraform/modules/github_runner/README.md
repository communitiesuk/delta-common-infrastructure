# GitHub runner

We use a GitHub Actions runner instance inside the VPC to deploy MarkLogic configuration changes through GitHub actions.

The runners are attached to a separate private repository <https://github.com/communitiesuk/delta-marklogic-deploy/>

## First time setup

The GitHub actions runner requires a short lived token to register with GitHub, this must be provided to terraform in the apply where the runner is created.

* Delete any existing runner for the environment
* Go to the create new runner page for the repo on GitHub: <https://github.com/communitiesuk/delta-marklogic-deploy/settings/actions/runners/new?arch=x64&os=linux>
* Copy the token from the setup steps
* Pass it as a variable to Terraform apply
* Check the runner appears online in GitHub
  * It will take a couple of minutes for the runner to initialise, you can check the logs in CloudWatch or on the instance

The instance is set to ignore_changes to its user data (which includes the runner token), so updates will need to be forced with e.g. `terraform taint`.
