############################################
# bootstrap/outputs.tf
############################################

output "state_bucket_name" {
  description = "S3 bucket name to use as `bucket` in environments/single/backend.tf."
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table name to use as `dynamodb_table` in environments/single/backend.tf."
  value       = aws_dynamodb_table.tf_lock.name
}
