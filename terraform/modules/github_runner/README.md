# GitHub runner

We use a GitHub Actions runner instance inside the VPC to deploy MarkLogic configuration changes through GitHub actions.

## First time setup

The GitHub actions runner requires a short lived token to register with GitHub, this must be provided to terraform in the apply where the runner is created.

* Go to the create new runner page for the repo on GitHub: <https://github.com/communitiesuk/delta-common-infrastructure/settings/actions/runners/new?arch=x64&os=linux>
* Copy the token from the setup steps
* Pass it as a variable to Terraform apply
* Back on GitHub tag the new runner with the name of the environment

The instance is set to ignore_changes to its user data (which includes the runner token), so updates will need to be forced with e.g. `terraform taint`.
