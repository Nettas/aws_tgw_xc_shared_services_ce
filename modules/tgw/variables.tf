############################################
# modules/tgw/variables.tf
#
# This module creates ONLY the Transit
# Gateway resource itself. Attachments,
# route tables, associations and
# propagations are all created explicitly
# in environments/single/main.tf rather
# than being abstracted away, because the
# whole point of this design is a very
# specific, non-default routing topology
# (per-VPC route tables, no default
# association/propagation). Keeping that
# logic visible in the root module makes
# the topology easy to read and reason
# about instead of hiding it behind a
# generic module.
############################################

variable "name" {
  description = "Name tag for the Transit Gateway."
  type        = string
}

variable "description" {
  description = "Description for the Transit Gateway."
  type        = string
  default     = "Hub-and-spoke Transit Gateway for shared-services CE design"
}

variable "amazon_side_asn" {
  description = "Private ASN for the Amazon side of the Transit Gateway BGP sessions."
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
