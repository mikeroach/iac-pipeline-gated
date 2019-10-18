# IaC Environment Pipeline - Gated Deployments

_"Vent radioactive gas? Y, E, S. Sound alertness horn? Y, E, S. Decalcify calcium ducts?  
Well, give me a Y, give me a... Hey! All I have to type is Y!_  
**--Homer Simpson, S07E07: King-Size Homer**

This repository contains Terraform definitions for environments which are ineligible for automated deployments due to enterprise policy or comfort concerns. It requires manual review and approval for changes during the journey towards building confidence in more sophisticated continuous delivery techniques necessary for modern technology organizations to achieve scale, while at the same time preserving the desired system state in Git free of external dependencies.

This [Terraform HCL](./main.tf) is effectively a wrapper to deploy a specific version of the [IaC Environment Template](https://github.com/mikeroach/iac-template-pipeline) with environment-appropriate variables. It and its [unsecret variables](./gated.tfvars) are updated by humans (e.g. to specify a new environment template module version), or by the [auto environment infrastructure pipeline](https://github.com/mikeroach/iac-pipeline-auto) to promote successfully tested application versions through use of the so-called ["GitOps Helper" script](./gitops-helper.sh).

#### Changes Workflow

1. Human or automated pipeline updates Terraform HCL/variables in feature branch and submits pull request.
1. Jenkins examines pull request, runs Terraform validation tests, then records test status and comments on pull request.
1. Human inspects Jenkins test status and manually merges pull request into master branch.
1. Jenkins examines master branch, repeats validation tests, applies Terraform plan in the live environment, and runs integration tests.

Note that while it's possible to manually apply changes directly to this environment, this pipeline should be treated as the second half of the [auto environment infrastructure pipeline](https://github.com/mikeroach/iac-pipeline-auto) with all application version upgrades promoted to ensure adequate testing coverage. The idea is that with comprehensive, robust testing and rich observability metrics at each stage of developing the code powering our infrastructure and application services, we have high confidence that our work is ready to be delivered to customers when our CI/CD pipelines indicate success so we can minimize our reliance on manual steps.