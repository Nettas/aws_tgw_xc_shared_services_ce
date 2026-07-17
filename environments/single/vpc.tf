############################################
# environments/single/vpc.tf
#
# Creates all four VPCs and their subnet-
# level routing. TGW attachments/route
# tables live in tgw.tf; this file only
# owns the VPCs themselves and the regular
# AWS route table entries inside each VPC
# (IGW default routes, and routes pointing
# at the Transit Gateway for
# TGW-reachable traffic).
############################################

# =============================================================================
# VPC A - Client A (single client node, single AZ, single /26)
# =============================================================================
module "vpc_client_a" {
  source = "../../modules/vpc"

  name                     = "${var.project_name}-client-a"
  primary_cidr_block       = local.vpc_client_a_cidr
  create_internet_gateway  = true

  subnets = [
    {
      name                    = "workload"
      cidr_block              = local.vpc_client_a_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = true
    }
  ]

  tags = local.common_tags
}

# Default route out to the Internet (client node needs egress independent
# of the F5 path, per current design decision - "yes access outside of F5
# path to start").
resource "aws_route" "client_a_default" {
  route_table_id         = module.vpc_client_a.route_table_ids["workload"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = module.vpc_client_a.internet_gateway_id
}

# Route to the Shared Services VPC's CIDR via the Transit Gateway - this is
# the only "east-west" path out of Client A (it cannot reach Client B or
# the on-prem-mimic VPC directly; see docs/decisions/0002 for why).
resource "aws_route" "client_a_to_shared_svcs" {
  route_table_id         = module.vpc_client_a.route_table_ids["workload"]
  destination_cidr_block = local.vpc_shared_svcs_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.client_a]
}

# =============================================================================
# VPC B - Client B (mirror of Client A)
# =============================================================================
module "vpc_client_b" {
  source = "../../modules/vpc"

  name                    = "${var.project_name}-client-b"
  primary_cidr_block      = local.vpc_client_b_cidr
  create_internet_gateway = true

  subnets = [
    {
      name                    = "workload"
      cidr_block              = local.vpc_client_b_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = true
    }
  ]

  tags = local.common_tags
}

resource "aws_route" "client_b_default" {
  route_table_id         = module.vpc_client_b.route_table_ids["workload"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = module.vpc_client_b.internet_gateway_id
}

resource "aws_route" "client_b_to_shared_svcs" {
  route_table_id         = module.vpc_client_b.route_table_ids["workload"]
  destination_cidr_block = local.vpc_shared_svcs_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.client_b]
}

# =============================================================================
# VPC C - Shared Services (hosts the F5 CE - two subnets: SLO + SLI)
# =============================================================================
module "vpc_shared_services" {
  source = "../../modules/vpc"

  name                    = "${var.project_name}-shared-services"
  primary_cidr_block      = local.vpc_shared_svcs_cidr
  create_internet_gateway = true

  subnets = [
    {
      name                    = "slo"
      cidr_block              = local.shared_svcs_slo_subnet_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = false # the CE gets its public reachability via an Elastic IP, not subnet auto-assign
    },
    {
      name                    = "sli"
      cidr_block              = local.shared_svcs_sli_subnet_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = false
    }
  ]

  tags = local.common_tags
}

# SLO subnet: default route to the Internet only. This is how the CE
# reaches F5 Regional Edges for registration and control/data tunnels.
# Deliberately NO Transit Gateway route here - north-south CE-to-RE traffic
# never needs to transit the TGW.
resource "aws_route" "shared_svcs_slo_default" {
  route_table_id         = module.vpc_shared_services.route_table_ids["slo"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = module.vpc_shared_services.internet_gateway_id
}

# SLI subnet: routes to every TGW-reachable workload/on-prem CIDR. This is
# the "hub" side - the CE uses this interface to discover/reach the spokes
# and to send published VIP traffic back out to them.
resource "aws_route" "shared_svcs_sli_to_client_a" {
  route_table_id         = module.vpc_shared_services.route_table_ids["sli"]
  destination_cidr_block = local.vpc_client_a_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

resource "aws_route" "shared_svcs_sli_to_client_b" {
  route_table_id         = module.vpc_shared_services.route_table_ids["sli"]
  destination_cidr_block = local.vpc_client_b_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

resource "aws_route" "shared_svcs_sli_to_onprem_classb" {
  route_table_id         = module.vpc_shared_services.route_table_ids["sli"]
  destination_cidr_block = local.onprem_classb_subnet_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

resource "aws_route" "shared_svcs_sli_to_onprem_classc" {
  route_table_id         = module.vpc_shared_services.route_table_ids["sli"]
  destination_cidr_block = local.onprem_classc_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

# =============================================================================
# VPC D - On-Prem Mimic (simulates an on-prem site with a Class B + Class C
# private range, attached to the TGW like any other spoke)
# =============================================================================
module "vpc_onprem_mimic" {
  source = "../../modules/vpc"

  name                    = "${var.project_name}-onprem-mimic"
  primary_cidr_block      = local.onprem_classb_vpc_cidr # 172.16.0.0/16 (Class B)
  secondary_cidr_blocks   = [local.onprem_classc_cidr]   # 192.168.50.0/24 (Class C)
  create_internet_gateway = true

  subnets = [
    {
      name                    = "classb"
      cidr_block              = local.onprem_classb_subnet_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = true
    },
    {
      name                    = "classc"
      cidr_block              = local.onprem_classc_cidr
      availability_zone       = local.availability_zone
      map_public_ip_on_launch = false
    }
  ]

  tags = local.common_tags
}

# The on-prem-mimic "host" (client node) lives in the Class B subnet, and
# that's also where the TGW attachment sits (see tgw.tf). Both the Class B
# and Class C subnets get the same two routes for consistency, even though
# only the Class B subnet has a workload in it today.
resource "aws_route" "onprem_classb_default" {
  route_table_id         = module.vpc_onprem_mimic.route_table_ids["classb"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = module.vpc_onprem_mimic.internet_gateway_id
}

resource "aws_route" "onprem_classb_to_shared_svcs" {
  route_table_id         = module.vpc_onprem_mimic.route_table_ids["classb"]
  destination_cidr_block = local.vpc_shared_svcs_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.onprem_mimic]
}

resource "aws_route" "onprem_classc_default" {
  route_table_id         = module.vpc_onprem_mimic.route_table_ids["classc"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = module.vpc_onprem_mimic.internet_gateway_id
}

resource "aws_route" "onprem_classc_to_shared_svcs" {
  route_table_id         = module.vpc_onprem_mimic.route_table_ids["classc"]
  destination_cidr_block = local.vpc_shared_svcs_cidr
  transit_gateway_id     = module.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.onprem_mimic]
}
