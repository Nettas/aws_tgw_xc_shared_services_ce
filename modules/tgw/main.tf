############################################
# modules/tgw/main.tf
############################################

resource "aws_ec2_transit_gateway" "this" {
  description     = var.description
  amazon_side_asn = var.amazon_side_asn

  # We manage association and propagation explicitly per-attachment in the
  # root module (four purpose-built route tables), so we turn off the
  # "everything goes in one default table" behavior here.
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  # DNS support lets resources across attached VPCs resolve each other's
  # private hostnames through the TGW where applicable.
  dns_support = "enable"

  tags = merge(var.tags, {
    Name = var.name
  })
}
