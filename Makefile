#terraform-cmd = docker run -i -e "TF_IN_AUTOMATION=1" -w /data --rm -v ${CURDIR}:/data hashicorp/terraform:0.12.6
terraform-cmd = TF_IN_AUTOMATION=1 terraform

TFVARS_SECRET ?= "./secrets/gated-secrets.tfvars"
TFVARS ?= "./gated.tfvars"

# Extract variables from Terraform environment
PROJECT_NAME := ${shell awk -F = '/^gcp_project_shortname/{gsub(/[ |\"]/, ""); print $$2}' $(TFVARS_SECRET) }
DOMAIN := ${shell awk -F = '/^dns_domain/{gsub(/[ |\"]/, ""); print $$2}' $(TFVARS_SECRET) }
#GANDI_API_KEY := ${shell awk -F = '/^gandi_api_key/{gsub(/[ |\"]/, ""); print $$2}' $(TFVARS_SECRET) }

VARS = -var-file=$(TFVARS) -var-file=$(TFVARS_SECRET)
BACKEND = -backend-config=./secrets/backend.tfvars

test: tf-init tf-fmt tf-validate

# Instantiate a new environment from scratch. - N/A with composed environment.
#environment: tf-init tf-plan network k8s apps

plan: tf-plan

apply: tf-apply

#destroy:
	#$(terraform-cmd) destroy -auto-approve $(VARS) -target=module.environment-auto.module.k8s-apps
	#$(terraform-cmd) destroy -auto-approve $(VARS) -target=module.environment-auto.module.k8s-infra
	#$(terraform-cmd) destroy -auto-approve $(VARS) -target=module.environment-auto.module.network
	# Quicker to just leave the stale DNS record when destroying ephemeral environments;
	# Gandi returns cache TTL of 1h for NXDOMAIN responses but 5m for A record response.
	#curl -X DELETE -H "Content-Type: application/json" -H "X-Api-Key: $(GANDI_API_KEY)" https://dns.api.gandi.net/api/v5/domains/$(DOMAIN)/records/$(PROJECT_NAME)/A
	#rm -f terraform.tfstate terraform.tfstate.backup

# Work around chicken/egg problem when variables.tf symlinked into temporarily nonexistent module directory.
tf-init: 
	#$(terraform-cmd) init -input=false $(BACKEND) $(VARS)
	if [ -e variables.tf ] ; then $(terraform-cmd) init -input=false $(BACKEND) $(VARS) ;\
		else \
			mv variables.tf variables.tfx ;\
			$(terraform-cmd) init -input=false $(BACKEND) $(VARS) ;\
			mv variables.tfx variables.tf ;\
	fi

tf-fmt:
	$(terraform-cmd) fmt -check -recursive -diff

#tf-lint: Revisit once this can recurse into module directories.
#	docker run -it --rm -w /data -v ${CURDIR}:/data wata727/tflint

tf-validate:
	$(terraform-cmd) validate $(VARS)

tf-plan:
	$(terraform-cmd) plan -input=false $(VARS)

tf-apply:
	$(terraform-cmd) apply -auto-approve -input=false $(VARS)

http-host:
	echo ${PROJECT_NAME}.${DOMAIN}