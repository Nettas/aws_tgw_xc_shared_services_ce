############################################
# modules/f5xc-ce-site/outputs.tf
############################################

output "site_name" {
  description = "Name of the F5XC Secure Mesh Site v2 object."
  value       = volterra_securemesh_site_v2.this.name
}

output "instance_id" {
  description = "EC2 instance ID of the CE node."
  value       = aws_instance.ce_node.id
}

output "slo_eni_id" {
  description = "ENI ID of the SLO (outside) interface - useful for reference if manually re-associating an EIP."
  value       = aws_network_interface.slo.id
}

output "sli_eni_id" {
  description = "ENI ID of the SLI (inside) interface."
  value       = aws_network_interface.sli.id
}

output "slo_private_ip" {
  description = "Private IP of the SLO interface."
  value       = aws_network_interface.slo.private_ip
}

output "sli_private_ip" {
  description = "Private IP of the SLI interface."
  value       = aws_network_interface.sli.private_ip
}

output "slo_public_ip" {
  description = "Elastic IP associated with the SLO interface."
  value       = aws_eip.slo.public_ip
}

output "sli_security_group_id" {
  description = "Security group ID protecting the SLI interface - referenced by the Transit Gateway attachment subnet route table docs and by any workload SGs that need to allow the CE."
  value       = aws_security_group.sli.id
}
