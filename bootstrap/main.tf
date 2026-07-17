############################################
# bootstrap/main.tf
#
# Creates the S3 bucket + DynamoDB lock table
# used as the remote state backend for
# environments/single. This has to be its OWN
# root module with its OWN (local) state,
# applied once, BEFORE you can point
# environments/single at an S3 backend -
# otherwise you have a chicken-and-egg problem
# (Terraform can't use a backend that doesn't
# exist yet).
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#   (note the outputs - you'll need the bucket
#    name and table name in
#    environments/single/backend.tf)
############################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Deliberately local state for the bootstrap module itself. This state
  # file is small, changes rarely, and is fine to keep local/checked into
  # a secure location outside git (see .gitignore) - it is NOT the state
  # for the actual environment.
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# S3 bucket to hold Terraform state for environments/single
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled" # protects against accidental state corruption/loss
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB table for state locking (prevents concurrent applies from
# corrupting state)
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}
