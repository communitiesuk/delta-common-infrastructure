## Distributed config

This repository is intended to contain the config for infrastructure shared by multiple applications in the Delta ecosystem. An applications own server should be defined in its own 

Terraform config in other repositories can read outputs from this repo by either using `terraform_remote_state` if there is no sensitive output or we could explicitly store relevant outputs somewhere such as S3. [See docs](https://www.terraform.io/language/state/remote-state-data) for more info. 

Pros:
* Keeping Terraform projects smaller improves performance of running plan/apply
* Avoid accidental or circular dependencies
* Sub teams can control the infrastructure of their own services without access to this repo.

Cons:
* There will be some duplicated Terraform code

## Reusable modules

The different environments each have their own folder for config and their own state. Resource definitions are reused between environments by creating reusable modules.

It is neat to have resources divided into modules anyway, but the reasons for this layout are:
* You can more easily check the differences between environments by viewing the root level files. 
* Production has its own AWS account for better security and isolation from testing, so it needs its own provider config

Cons:
* There is some duplication, such as within outputs.tf or variables.tf 