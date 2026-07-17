############################################
# environments/single/versions.tf
############################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Official F5 Distributed Cloud ("Volterra") provider - used for the
    # Secure Mesh Site v2 object and the one-time registration token.
    # https://registry.terraform.io/providers/volterraedge/volterra/latest
    volterra = {
      source  = "volterraedge/volterra"
      version = "~> 0.11"
    }
  }
}
