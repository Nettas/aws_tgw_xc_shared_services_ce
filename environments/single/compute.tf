############################################
# environments/single/compute.tf
############################################

# =============================================================================
# Client nodes - one Amazon Linux instance per spoke VPC
# =============================================================================
module "client_a_node" {
  source = "../../modules/client-node"

  name                 = "${var.project_name}-client-a"
  subnet_id            = module.vpc_client_a.subnet_ids["workload"]
  security_group_ids   = [aws_security_group.client_a.id]
  associate_public_ip  = true
  key_name             = var.ssh_key_name

  tags = local.common_tags
}

module "client_b_node" {
  source = "../../modules/client-node"

  name                = "${var.project_name}-client-b"
  subnet_id           = module.vpc_client_b.subnet_ids["workload"]
  security_group_ids  = [aws_security_group.client_b.id]
  associate_public_ip = true
  key_name            = var.ssh_key_name

  tags = local.common_tags
}

module "onprem_mimic_node" {
  source = "../../modules/client-node"

  name                = "${var.project_name}-onprem-mimic"
  subnet_id           = module.vpc_onprem_mimic.subnet_ids["classb"]
  security_group_ids  = [aws_security_group.onprem_mimic.id]
  associate_public_ip = true
  key_name            = var.ssh_key_name

  tags = local.common_tags
}

# =============================================================================
# F5 Distributed Cloud Secure Mesh Site v2 - Shared Services CE
# =============================================================================
module "shared_services_ce" {
  source = "../../modules/f5xc-ce-site"

  site_name = var.f5xc_site_name
  latitude  = var.f5xc_site_latitude
  longitude = var.f5xc_site_longitude

  vpc_id        = module.vpc_shared_services.vpc_id
  slo_subnet_id = module.vpc_shared_services.subnet_ids["slo"]
  sli_subnet_id = module.vpc_shared_services.subnet_ids["sli"]

  key_name           = var.ssh_key_name
  mgmt_allowed_cidrs = var.mgmt_allowed_cidrs
  workload_cidrs     = local.workload_cidrs

  tags = local.common_tags
}

# =============================================================================
# F5XC External Connector <-> AWS Transit Gateway peering (STUB)
#
# See modules/f5xc-external-connector/README.md - this module does not yet
# create real resources pending confirmation of the current resource
# schema for the External Connector object and AWS's third-party TGW
# tunnel-termination attachment.
# =============================================================================
module "shared_services_external_connector" {
  source = "../../modules/f5xc-external-connector"

  connector_name      = "${var.project_name}-external-connector"
  site_name           = module.shared_services_ce.site_name
  transit_gateway_id  = module.tgw.id

  tags = local.common_tags
}
