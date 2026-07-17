############################################
# modules/f5xc-external-connector/main.tf
#
# STUB MODULE - see README.md in this folder.
#
# This module currently creates NO resources. It exists as a placeholder
# so the calling root module (environments/single/main.tf) has a stable
# module block to fill in once the F5XC External Connector resource
# schema and the AWS third-party TGW tunnel-termination attachment
# resource are confirmed.
#
# --- Sketch of what will likely go here (DO NOT UNCOMMENT AS-IS) -----------
#
# resource "volterra_external_connector" "this" {
#   name      = var.connector_name
#   namespace = var.namespace
#
#   # Likely shape, based on how other F5XC "connector" objects reference
#   # a site and a cloud-side peering target - VERIFY against current
#   # provider docs before uncommenting:
#   site {
#     name = var.site_name
#   }
#
#   aws_tgw_peering {
#     transit_gateway_id = var.transit_gateway_id
#   }
# }
#
# On the AWS side, third-party tunnel termination to Transit Gateway may
# require its own attachment/connect-peer resources distinct from a plain
# `aws_ec2_transit_gateway_vpc_attachment` - confirm the current AWS
# construct (this feature is newer than this repo's Terraform AWS provider
# knowledge) before adding those resources here.
# -----------------------------------------------------------------------------

# Intentionally no resources yet. A `null_resource` marker below just makes
# `terraform plan` on this module a visible no-op instead of an empty file,
# and gives you a place to hang a `local-exec` reminder if useful during
# bring-up.
resource "null_resource" "not_yet_implemented" {
  triggers = {
    note = "f5xc-external-connector module is a stub - see README.md before relying on this in an apply."
  }
}
