terraform {
  backend "gcs" {}
}

module "environment-gated" {
  source                            = "github.com/mikeroach/iac-template-pipeline?ref=v3"
  dns_hostname                      = var.dns_hostname
  dns_domain                        = var.dns_domain
  dockerhub_credentials             = var.dockerhub_credentials
  gandi_api_key                     = var.gandi_api_key
  gcp_credentials                   = var.gcp_credentials
  gcp_project_shortname             = var.gcp_project_shortname
  gcp_organization_id               = var.gcp_organization_id
  gcp_region                        = var.gcp_region
  gcp_zone                          = var.gcp_zone
  iac_bootstrap_tfstate_bucket      = var.iac_bootstrap_tfstate_bucket
  iac_bootstrap_tfstate_prefix      = var.iac_bootstrap_tfstate_prefix
  iac_bootstrap_tfstate_credentials = var.iac_bootstrap_tfstate_credentials
  k8s_preemptible                   = var.k8s_preemptible
  subnet_cidr                       = var.subnet_cidr
  service_aphorismophilia_namespace = var.service_aphorismophilia_namespace
  service_aphorismophilia_version   = var.service_aphorismophilia_version
}