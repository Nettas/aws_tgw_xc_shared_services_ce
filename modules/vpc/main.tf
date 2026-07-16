############################################
# modules/vpc/main.tf
#
# Creates: 1 VPC, optional secondary CIDR
# associations, an optional Internet Gateway,
# N subnets, and one route table per subnet
# (associated 1:1 with that subnet).
#
# NOTE: This module intentionally does NOT
# add any routes (IGW default route, TGW
# routes, etc). Routes are added by the
# calling root module via `aws_route`
# resources that reference the route table
# IDs exported below. This keeps the VPC
# module reusable across very different
# routing needs (e.g. the Shared Services
# VPC's SLO subnet routes out to the
# Internet, while its SLI subnet routes
# in to the Transit Gateway).
############################################

# ---------------------------------------------------------------------------
# The VPC itself
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.primary_cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, {
    Name = var.name
  })
}

# ---------------------------------------------------------------------------
# Optional secondary CIDR block(s), e.g. the on-prem-mimic VPC's Class C
# range in addition to its primary Class B range.
# ---------------------------------------------------------------------------
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  for_each = toset(var.secondary_cidr_blocks)

  vpc_id     = aws_vpc.this.id
  cidr_block = each.value
}

# ---------------------------------------------------------------------------
# Internet Gateway (optional per VPC)
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

# ---------------------------------------------------------------------------
# Subnets - one per entry in var.subnets
#
# depends_on the secondary CIDR association so that subnets carved out of
# a secondary CIDR block (e.g. the on-prem-mimic Class C subnet) aren't
# created before AWS has finished associating that CIDR with the VPC.
# ---------------------------------------------------------------------------
resource "aws_subnet" "this" {
  for_each = { for s in var.subnets : s.name => s }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value.name}"
  })

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

# ---------------------------------------------------------------------------
# One dedicated route table per subnet, associated 1:1
# ---------------------------------------------------------------------------
resource "aws_route_table" "this" {
  for_each = { for s in var.subnets : s.name => s }

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value.name}-rt"
  })
}

resource "aws_route_table_association" "this" {
  for_each = { for s in var.subnets : s.name => s }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}
