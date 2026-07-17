############################################
# bootstrap/variables.tf
############################################

variable "region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state. S3 bucket names are global across all of AWS, so include an account/org-specific suffix."
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  type        = string
  default     = "aws-tgw-xc-sharedservice-ce-tf-lock"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default = {
    Project   = "aws-tgw-xc-sharedservice-ce"
    ManagedBy = "terraform"
  }
}
