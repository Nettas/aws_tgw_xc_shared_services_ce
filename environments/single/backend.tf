############################################
# environments/single/backend.tf
#
# Remote state in S3 with DynamoDB locking.
# The bucket/table referenced here must
# already exist - created by ../../bootstrap
# (see bootstrap/README or root README for
# the one-time bootstrap steps).
#
# Terraform does not allow variables in a
# `backend` block, so these values are
# literal. Update them to match the outputs
# from `terraform apply` in bootstrap/, then
# never change the key/region without a
# deliberate state migration
# (`terraform init -migrate-state`).
############################################

terraform {
  backend "s3" {
    bucket         = "CHANGE-ME-tf-state-aws-tgw-xc-sharedservice-ce"
    key            = "environments/single/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "aws-tgw-xc-sharedservice-ce-tf-lock"
    encrypt        = true
  }
}
