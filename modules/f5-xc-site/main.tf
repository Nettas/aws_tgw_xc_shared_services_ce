############################################
# modules/f5xc-ce-site/main.tf
############################################

# ---------------------------------------------------------------------------
# Look up the F5 Marketplace CE AMI ID via the SSM parameter F5 publishes.
# You must have subscribed to the F5 Distributed Cloud CE listing in AWS
# Marketplace for this account/region first.
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "ce_ami" {
  name = var.marketplace_ami_ssm_parameter
}

# Read the subnet CIDRs back so we can compute the gateway IP (first usable
# address, .1) for the cloud-init static IP configuration without asking
# the caller to pass CIDRs in twice.
data "aws_subnet" "slo" {
  id = var.slo_subnet_id
}

data "aws_subnet" "sli" {
  id = var.sli_subnet_id
}

# =============================================================================
# F5 Distributed Cloud objects: Site + one-time registration Token
# =============================================================================

# The Secure Mesh Site v2 object represents this CE in F5 Distributed Cloud
# Console. "not_managed" tells F5XC that WE (via Terraform/AWS) are
# responsible for creating the underlying compute, as opposed to F5XC
# orchestrating the cloud resources itself (which is the legacy "AWS VPC
# Site" / "AWS TGW Site" orchestrated model we are explicitly NOT using).
resource "volterra_securemesh_site_v2" "this" {
  name      = var.site_name
  namespace = var.namespace

  block_all_services   = false
  logs_streaming_disabled = true
  enable_ha            = false # single-node site, per current design decision

  labels = {
    "ves.io/provider" = "ves-io-AWS"
  }

  aws {
    not_managed {}
  }

  re_select {
    geo_proximity = true
  }

  latitude  = var.latitude
  longitude = var.longitude
}

# A one-time node token, valid 24h, consumed by the cloud-init user_data to
# register the node against the Site object above. Because this is a
# single-node (non-HA) site there is only one token to manage; for a 3-node
# HA site, F5 explicitly recommends generating/consuming tokens
# sequentially rather than all at once - see docs/decisions/0001 for why we
# are not doing HA in this iteration.
#
# NOTE: verify the exported attribute name (`token` below) against the
# `volterraedge/volterra` provider version you pin in versions.tf - the
# attribute name has been stable across recent releases but provider
# schemas can change between major versions.
resource "volterra_token" "this" {
  depends_on = [volterra_securemesh_site_v2.this]

  name      = "${var.site_name}-token"
  namespace = var.namespace
  type      = 1 # SITE token type
  site_name = volterra_securemesh_site_v2.this.name
}

# =============================================================================
# Security Groups
# =============================================================================

# --- SLO (outside) security group -------------------------------------------
# Per F5 guidance: outbound is allow-all (the CE only needs to be able to
# *initiate* the tunnel to F5 Regional Edges), and inbound is minimal -
# ICMP for troubleshooting, plus optional SSH / local-UI access from a
# trusted management CIDR only.
resource "aws_security_group" "slo" {
  name        = "${var.site_name}-slo-sg"
  description = "F5 CE SLO (outside) interface - RE tunnels + optional mgmt access"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.site_name}-slo-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "slo_icmp" {
  security_group_id = aws_security_group.slo.id
  description       = "ICMP for troubleshooting"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "slo_ssh" {
  for_each = toset(var.mgmt_allowed_cidrs)

  security_group_id = aws_security_group.slo.id
  description       = "SSH for troubleshooting from trusted management CIDR"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "slo_local_ui" {
  for_each = toset(var.mgmt_allowed_cidrs)

  security_group_id = aws_security_group.slo.id
  description       = "F5 CE local UI (port 65500) from trusted management CIDR"
  ip_protocol       = "tcp"
  from_port         = 65500
  to_port           = 65500
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "slo_all" {
  security_group_id = aws_security_group.slo.id
  description       = "Allow all outbound (RE tunnel establishment, registration, updates)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- SLI (inside) security group --------------------------------------------
# Faces the Transit Gateway attachment. Needs to talk to whatever is
# reachable via the TGW (the two client VPCs + the on-prem-mimic VPC's two
# CIDR ranges), plus itself for multi-node clusters (not used in single-node
# mode, but harmless to include for a future HA upgrade).
resource "aws_security_group" "sli" {
  name        = "${var.site_name}-sli-sg"
  description = "F5 CE SLI (inside) interface - workload traffic via Transit Gateway"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.site_name}-sli-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "sli_workload" {
  for_each = toset(var.workload_cidrs)

  security_group_id = aws_security_group.sli.id
  description       = "Traffic from TGW-reachable workload/on-prem CIDR"
  ip_protocol       = "-1"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "sli_self" {
  security_group_id            = aws_security_group.sli.id
  description                   = "Inter-node traffic (future multi-node HA upgrade)"
  ip_protocol                   = "-1"
  referenced_security_group_id  = aws_security_group.sli.id
}

resource "aws_vpc_security_group_egress_rule" "sli_all" {
  security_group_id = aws_security_group.sli.id
  description       = "Allow all outbound toward TGW-reachable workloads"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# Network interfaces
#
# We let AWS auto-assign the private IP from each subnet (no `private_ips`
# argument), then feed that same address + subnet gateway back into the
# cloud-init static IP configuration for the SLO interface. This keeps the
# ENI's IP and the CE's own understanding of its IP in lockstep, which
# matters because F5 does not allow the SLO IP to be changed post-deploy.
# =============================================================================

resource "aws_network_interface" "slo" {
  subnet_id         = var.slo_subnet_id
  security_groups   = [aws_security_group.slo.id]
  source_dest_check = false # required: the CE is a router/NVA, not an endpoint

  tags = merge(var.tags, { Name = "${var.site_name}-slo-eni" })
}

resource "aws_network_interface" "sli" {
  subnet_id         = var.sli_subnet_id
  security_groups   = [aws_security_group.sli.id]
  source_dest_check = false # required: TGW-facing side also routes transit traffic

  tags = merge(var.tags, { Name = "${var.site_name}-sli-eni" })
}

# Elastic IP for outbound Internet access on the SLO interface (RE tunnels,
# registration). Per F5 docs this is the simplest of several valid methods
# (NAT Gateway is another).
resource "aws_eip" "slo" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.site_name}-slo-eip" })
}

resource "aws_eip_association" "slo" {
  allocation_id        = aws_eip.slo.id
  network_interface_id = aws_network_interface.slo.id
}

# =============================================================================
# The CE EC2 instance
# =============================================================================

resource "aws_instance" "ce_node" {
  ami           = data.aws_ssm_parameter.ce_ami.value
  instance_type = var.instance_type
  key_name      = var.key_name

  # Interface 0 = SLO (must be the first/default interface per F5 docs),
  # interface 1 = SLI.
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.slo.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.sli.id
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  # NOTE (fully-automated token flow): the token is only known after
  # `volterra_token.this` is created, and the SLO ENI's private IP/gateway
  # are only known after the ENI exists - so this instance implicitly
  # depends on both via the interpolations below. No manual step is
  # required for a normal `terraform apply`.
  user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    token               = volterra_token.this.token
    slo_ip              = aws_network_interface.slo.private_ip
    slo_prefix_length   = split("/", data.aws_subnet.slo.cidr_block)[1]
    slo_gateway         = cidrhost(data.aws_subnet.slo.cidr_block, 1)
  }))

  tags = merge(var.tags, { Name = var.site_name })

  lifecycle {
    # The SLO IP cannot be changed post-deploy per F5 docs; if you need a
    # new address you must destroy and recreate the node, not modify it
    # in place.
    create_before_destroy = false
  }
}
