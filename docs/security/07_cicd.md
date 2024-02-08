# CI/CD

GitHub Actions is used for CI/CD.

Where workflows require AWS access, AWS users are created in the relevant account for CI/CD users.
AWS access keys are then created and stored as GitHub Actions secrets.

All repositories are stored under DLUHC's communitiesuk GitHub organisation.

## Terraform

The Terraform code is split across several repositories, but the setup for all of them is similar.

A dev account (staging and test environments) key with read only access is available for running Terraform plans for all pull requests.
A dev account admin key is stored as an environment secret and is only accessible from the main branch.
Branch protections are in place for the this repository, but not delta or common-payments-module, as they would be incompatible with the current supplier's development process.

Terraform deployments to production are done manually with named accounts.

## Application deployments

Application deployment bundles are deployed to an appropriate repository (ECR or CodeArtifact).
The same repository is shared by all environments.

A "CI" user is used to push artifacts to the repositories, and is available as a repository secret.
Artifacts used by production are immutable, so this account cannot be used to affect production services.

Deployments are either managed by Terraform or by workflows within the repositories which have AWS access keys with the required permissions as environment secrets.

## MarkLogic deployments

Deployments to MarkLogic require direct network access.
For this we use an EC2 instance inside the VPC as a GitHub runner.
Access controls around GitHub runners are limited, so we attach them to a separate repository.

Deployments from this repository also use an AWS user with access to required secrets like the MarkLogic admin password.
This user is stored as environment secrets, with access control via branch protection for test/staging, and named approvers for production.

## Effective privileges

| Repository                  | Permission | Dev AWS access      | Prod AWS access     |
|-----------------------------|------------|---------------------|---------------------|
| communitiesuk organisation  | Admin      | Admin               | All below           |
| delta-common-infrastructure | Read       | None                | None                |
| delta-common-infrastructure | Write      | Plan\*              | None                |
| delta-common-infrastructure | Admin      | Admin               | None                |
| delta                       | Read       | None                | None                |
| delta                       | Write      | Admin               | Push artefacts\*\*  |
| delta                       | Admin      | Admin               | Plan + Deploy Delta website |
| common-payments-module      | Read       | None                | None                |
| common-payments-module      | Write      | Admin               | Push artefacts\*\*  |
| common-payments-module      | Admin      | Admin               | Plan                |
| delta-orbeon                | Read       | None                | None                |
| delta-orbeon                | Write      | None                | Push artefacts\*\*  |
| delta-orbeon                | Admin      | None                | Push artefacts\*\*  |
| delta-marklogic-deploy      | Read       | None                | None                |
| delta-marklogic-deploy      | Write      | Runner + ML secrets | Runner†             |
| delta-marklogic-deploy      | Admin      | Runner + ML secrets | Runner + ML secrets |
| delta-auth-service          | Write      | None                | Push artefacts\*\*  |
| delta-auth-service          | Maintain   | Admin               | Push artefacts\*\*  |

\* Plan - read only access to the account, including reading the terraform state and some secrets.

\*\* Being able to push artefacts to production also affects dev as they share artefact repositories. Artefacts are immutable, so this cannot be used to directly affect running production services.

† In practice, a user with access to the GitHub runner in an environment may be able to extract the MarkLogic secrets from a previous run. Repository write access should therefore be carefully controlled.

Where "Maintain" isn't specified the permissions are the same as "Write".

The named approvers for a given GitHub Actions Environment or branch protection rule will also have elevated access, though currently they are all also repository admins.
