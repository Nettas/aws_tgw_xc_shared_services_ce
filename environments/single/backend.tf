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
  /* Using local state for now — bootstrap/ (S3+DynamoDB backend) skipped
     for this session. Re-enable before treating this as anything but a
     solo/lab environment; local state has no locking and no durability
     beyond this machine.
  backend "s3" {
    bucket         = "your-bucket-name"
    key            = "single/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "your-lock-table"
    encrypt        = true
  }
  */
}
