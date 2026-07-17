############################################
# environments/single/tgw.tf
#
# The Transit Gateway topology for this
# design:
#
#   4 attachments  -> 4 dedicated route tables (1:1 association)
#
#   - rtb-client-a       <- associated with the Client A attachment
#                           propagates:  (nothing in - it's a pure spoke)
#   - rtb-client-b       <- associated with the Client B attachment
#                           propagates:  (nothing in - it's a pure spoke)
#   - rtb-shared-services<- associated with the Shared Services attachment
#                           propagates in: Client A, Client B, On-Prem Mimic
#   - rtb-onprem-mimic   <- associated with the On-Prem Mimic attachment
#                           propagates:  (nothing in - it's a pure spoke)
#
#   And each spoke table (client-a, client-b, onprem-mimic) receives ONE
#   propagated route: the Shared Services VPC's CIDR, propagated in by the
#   Shared Services attachment.
#
# Net effect: Client A, Client B, and the On-Prem Mimic VPC can each only
# reach the Shared Services VPC (where the F5 CE lives) over the TGW - they
# cannot reach each other directly. The Shared Services VPC (and therefore
# the CE) can reach all three spokes. This forces all east-west traffic
# through the CE, which is the point of putting F5 in a "shared services"
# position: it discovers origins and publishes VIPs that the spokes reach
# only via the hub.
############################################

# =============================================================================
# The Transit Gateway itself
# =============================================================================
module "tgw" {
  source = "../../modules/tgw"

  name = "${var.project_name}-tgw"
  tags = local.common_tags
}

# =============================================================================
# VPC Attachments (one per VPC/spoke)
# =============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "client_a" {
  transit_gateway_id = module.tgw.id
  vpc_id             = module.vpc_client_a.vpc_id
  subnet_ids         = [module.vpc_client_a.subnet_ids["workload"]]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(local.common_tags, { Name = "${var.project_name}-attach-client-a" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "client_b" {
  transit_gateway_id = module.tgw.id
  vpc_id             = module.vpc_client_b.vpc_id
  subnet_ids         = [module.vpc_client_b.subnet_ids["workload"]]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(local.common_tags, { Name = "${var.project_name}-attach-client-b" })
}

# Shared Services attaches via its SLI (inside) subnet - that's the
# interface that should carry Transit Gateway traffic. The SLO subnet
# never touches the TGW.
resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  transit_gateway_id = module.tgw.id
  vpc_id             = module.vpc_shared_services.vpc_id
  subnet_ids         = [module.vpc_shared_services.subnet_ids["sli"]]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(local.common_tags, { Name = "${var.project_name}-attach-shared-services" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "onprem_mimic" {
  transit_gateway_id = module.tgw.id
  vpc_id             = module.vpc_onprem_mimic.vpc_id
  subnet_ids         = [module.vpc_onprem_mimic.subnet_ids["classb"]]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation  = false

  tags = merge(local.common_tags, { Name = "${var.project_name}-attach-onprem-mimic" })
}

# =============================================================================
# Four dedicated Transit Gateway route tables, one per attachment
# =============================================================================
resource "aws_ec2_transit_gateway_route_table" "client_a" {
  transit_gateway_id = module.tgw.id
  tags                = merge(local.common_tags, { Name = "${var.project_name}-rtb-client-a" })
}

resource "aws_ec2_transit_gateway_route_table" "client_b" {
  transit_gateway_id = module.tgw.id
  tags                = merge(local.common_tags, { Name = "${var.project_name}-rtb-client-b" })
}

resource "aws_ec2_transit_gateway_route_table" "shared_services" {
  transit_gateway_id = module.tgw.id
  tags                = merge(local.common_tags, { Name = "${var.project_name}-rtb-shared-services" })
}

resource "aws_ec2_transit_gateway_route_table" "onprem_mimic" {
  transit_gateway_id = module.tgw.id
  tags                = merge(local.common_tags, { Name = "${var.project_name}-rtb-onprem-mimic" })
}

# =============================================================================
# Associations: each attachment is associated with exactly ONE route table
# - this is what determines which table's routes govern traffic FROM that
# attachment.
# =============================================================================
resource "aws_ec2_transit_gateway_route_table_association" "client_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.client_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.client_a.id
}

resource "aws_ec2_transit_gateway_route_table_association" "client_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.client_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.client_b.id
}

resource "aws_ec2_transit_gateway_route_table_association" "shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_association" "onprem_mimic" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.onprem_mimic.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem_mimic.id
}

# =============================================================================
# Propagations: this is what determines which OTHER tables learn about an
# attachment's routes (its VPC CIDR(s)).
# =============================================================================

# Each spoke propagates its own CIDR(s) into the Shared Services table, so
# the CE (sitting on the Shared Services attachment) can see and route to
# all three spokes.
resource "aws_ec2_transit_gateway_route_table_propagation" "client_a_into_shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.client_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "client_b_into_shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.client_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "onprem_mimic_into_shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.onprem_mimic.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

# Shared Services propagates its own CIDR into each spoke's table, so each
# spoke can reach the Shared Services VPC (and therefore the CE-published
# VIP(s)) - but, critically, NOT into each other's tables. This is what
# enforces "spokes can only reach the hub, never each other directly."
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_into_client_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.client_a.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_into_client_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.client_b.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_into_onprem_mimic" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem_mimic.id
}
