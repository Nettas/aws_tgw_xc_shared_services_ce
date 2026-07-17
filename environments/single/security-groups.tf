############################################
# environments/single/security-groups.tf
#
# Simple security groups for the three
# "client" test nodes (Client A, Client B,
# On-Prem Mimic host). Each allows SSH/ICMP
# from the management CIDR list and allows
# all outbound - these are lab test hosts,
# not production workloads.
############################################

resource "aws_security_group" "client_a" {
  name        = "${var.project_name}-client-a-sg"
  description = "Client A test node - SSH/ICMP from mgmt CIDRs, all egress"
  vpc_id      = module.vpc_client_a.vpc_id

  tags = merge(local.common_tags, { Name = "${var.project_name}-client-a-sg" })
}

resource "aws_security_group" "client_b" {
  name        = "${var.project_name}-client-b-sg"
  description = "Client B test node - SSH/ICMP from mgmt CIDRs, all egress"
  vpc_id      = module.vpc_client_b.vpc_id

  tags = merge(local.common_tags, { Name = "${var.project_name}-client-b-sg" })
}

resource "aws_security_group" "onprem_mimic" {
  name        = "${var.project_name}-onprem-mimic-sg"
  description = "On-prem-mimic test node - SSH/ICMP from mgmt CIDRs, all egress"
  vpc_id      = module.vpc_onprem_mimic.vpc_id

  tags = merge(local.common_tags, { Name = "${var.project_name}-onprem-mimic-sg" })
}

# ---------------------------------------------------------------------------
# Shared rule set applied identically to all three client SGs above via
# for_each over a map of {sg_key => sg_id}.
# ---------------------------------------------------------------------------
locals {
  client_sgs = {
    client_a     = aws_security_group.client_a.id
    client_b     = aws_security_group.client_b.id
    onprem_mimic = aws_security_group.onprem_mimic.id
  }
}

resource "aws_vpc_security_group_ingress_rule" "client_ssh" {
  for_each = { for pair in setproduct(keys(local.client_sgs), var.mgmt_allowed_cidrs) : "${pair[0]}-${pair[1]}" => {
    sg_id = local.client_sgs[pair[0]]
    cidr  = pair[1]
  } }

  security_group_id = each.value.sg_id
  description       = "SSH from trusted management CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_ingress_rule" "client_icmp" {
  for_each = local.client_sgs

  security_group_id = each.value
  description       = "ICMP for connectivity testing across the Transit Gateway"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "client_all_egress" {
  for_each = local.client_sgs

  security_group_id = each.value
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
