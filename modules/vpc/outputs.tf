############################################
# modules/vpc/outputs.tf
############################################

output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway, if created."
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "subnet_ids" {
  description = "Map of subnet name -> subnet ID."
  value       = { for name, s in aws_subnet.this : name => s.id }
}

output "subnet_cidrs" {
  description = "Map of subnet name -> subnet CIDR block."
  value       = { for name, s in aws_subnet.this : name => s.cidr_block }
}

output "route_table_ids" {
  description = "Map of subnet name -> the dedicated route table ID for that subnet."
  value       = { for name, rt in aws_route_table.this : name => rt.id }
}
