############################################
# environments/single/providers.tf
############################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# F5 Distributed Cloud ("Volterra") provider. Authenticates using a P12 API
# client certificate downloaded from F5 Distributed Cloud Console under
# your tenant's API Credentials page. Never commit the actual .p12 file or
# its path contents to git - only its filesystem path is referenced here,
# and that path is supplied via a variable (see terraform.tfvars, which is
# itself gitignored).
provider "volterra" {
  api_p12_file = var.f5xc_api_p12_file
  url          = var.f5xc_api_url
}
