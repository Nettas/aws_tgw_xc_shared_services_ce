############################################
# environments/single/outputs.tf
############################################

# --- VPCs ---------------------------------------------------------------------

output "vpc_ids" {
  description = "Map of VPC name -> VPC ID for all four VPCs."
  value = {
    client_a        = module.vpc_client_a.vpc_id
    client_b        = module.vpc_client_b.vpc_id
    shared_services = module.vpc_shared_services.vpc_id
    onprem_mimic    = module.vpc_onprem_mimic.vpc_id
  }
}

output "vpc_cidrs" {
  description = "CIDR plan summary for quick reference."
  value = {
    client_a              = local.vpc_client_a_cidr
    client_b               = local.vpc_client_b_cidr
    shared_services         = local.vpc_shared_svcs_cidr
    shared_services_slo     = local.shared_svcs_slo_subnet_cidr
    shared_services_sli     = local.shared_svcs_sli_subnet_cidr
    onprem_mimic_class_b    = local.onprem_classb_subnet_cidr
    onprem_mimic_class_c    = local.onprem_classc_cidr
    reserved_unused         = local.vpc_reserved_cidr
  }
}

# --- Transit Gateway ------------------------------------------------------------

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = module.tgw.id
}

output "transit_gateway_route_table_ids" {
  description = "Map of TGW route table name -> ID, for use in the AWS console or CLI when validating routes."
  value = {
    client_a        = aws_ec2_transit_gateway_route_table.client_a.id
    client_b        = aws_ec2_transit_gateway_route_table.client_b.id
    shared_services = aws_ec2_transit_gateway_route_table.shared_services.id
    onprem_mimic    = aws_ec2_transit_gateway_route_table.onprem_mimic.id
  }
}

# --- Compute --------------------------------------------------------------------

output "client_node_private_ips" {
  description = "Private IPs of the three client test nodes."
  value = {
    client_a     = module.client_a_node.private_ip
    client_b     = module.client_b_node.private_ip
    onprem_mimic = module.onprem_mimic_node.private_ip
  }
}

output "client_node_public_ips" {
  description = "Public IPs of the three client test nodes (for SSH from your mgmt CIDR)."
  value = {
    client_a     = module.client_a_node.public_ip
    client_b     = module.client_b_node.public_ip
    onprem_mimic = module.onprem_mimic_node.public_ip
  }
}

# --- F5 CE ------------------------------------------------------------------------

output "f5_ce_site_name" {
  description = "Name of the F5XC Secure Mesh Site v2 object."
  value       = module.shared_services_ce.site_name
}

output "f5_ce_slo_public_ip" {
  description = "Elastic IP on the CE's SLO interface - use this to reach the local UI (port 65500) or SSH from a management CIDR."
  value       = module.shared_services_ce.slo_public_ip
}

output "f5_ce_sli_private_ip" {
  description = "Private IP of the CE's SLI (inside) interface, facing the Transit Gateway."
  value       = module.shared_services_ce.sli_private_ip
}

output "f5xc_external_connector_status" {
  description = "Reminder output from the stub External Connector module."
  value       = module.shared_services_external_connector.status
}
