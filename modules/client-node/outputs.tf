############################################
# modules/client-node/outputs.tf
############################################

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Primary private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address, if one was assigned."
  value       = aws_instance.this.public_ip
}
