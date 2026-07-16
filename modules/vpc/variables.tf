############################################
# modules/vpc/variables.tf
#
# Generic VPC module used for all four VPCs
# in this design (Client A, Client B, Shared
# Services, and the On-Prem Mimic VPC).
#
# It supports multiple CIDR blocks per VPC
# (needed for the on-prem mimic VPC, which
# carries both a Class B and a Class C
# private range) and an arbitrary list of
# subnets, each getting its own route table
# so that different subnets in the same VPC
# (e.g. SLO vs SLI on the Shared Services VPC)
# can have completely different routing.
############################################

variable "name" {
  description = "Friendly name for this VPC, used for tagging and resource naming (e.g. \"client-a\")."
  type        = string
}

variable "primary_cidr_block" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
}

variable "secondary_cidr_blocks" {
  description = <<-EOT
    Optional additional IPv4 CIDR blocks to associate with the VPC.
    Used by the on-prem-mimic VPC to carry a second (Class C) private
    range alongside its primary Class B range, simulating a site that
    advertises two disjoint on-prem networks.
  EOT
  type    = list(string)
  default = []
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "create_internet_gateway" {
  description = "Whether to create and attach an Internet Gateway to this VPC."
  type        = bool
  default     = true
}

variable "subnets" {
  description = <<-EOT
    List of subnets to create in this VPC. Each subnet gets its own
    dedicated route table so callers can attach different routes
    (IGW default route, TGW routes, etc.) per subnet.
  EOT
  type = list(object({
    name                    = string
    cidr_block              = string
    availability_zone       = string
    map_public_ip_on_launch = optional(bool, false)
  }))
}

variable "tags" {
  description = "Common tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
