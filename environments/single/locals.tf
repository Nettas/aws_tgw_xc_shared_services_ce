############################################
# environments/single/locals.tf
#
# Central place for the CIDR plan and any
# other values shared across the vpc/tgw/
# compute .tf files in this root module.
# Keeping the CIDR plan here (instead of
# scattered across files) makes it much
# easier to audit the addressing scheme in
# one glance.
############################################

locals {
  # ---------------------------------------------------------------------------
  # Single Availability Zone for this iteration of the design. See
  # docs/decisions/0001-single-az-vs-multi-az.md for the tradeoffs of moving
  # to multi-AZ later.
  # ---------------------------------------------------------------------------
  availability_zone = "us-east-2a"

  # ---------------------------------------------------------------------------
  # CIDR plan: 10.0.0.0/24 carved into three /26 blocks, one per "10.0.0.0
  # space" VPC (Client A, Client B, Shared Services). A fourth /26
  # (10.0.0.192/26) is reserved and intentionally unused for now.
  # ---------------------------------------------------------------------------
  vpc_client_a_cidr      = "10.0.0.0/26"   # 10.0.0.0   - 10.0.0.63
  vpc_client_b_cidr      = "10.0.0.64/26"  # 10.0.0.64  - 10.0.0.127
  vpc_shared_svcs_cidr   = "10.0.0.128/26" # 10.0.0.128 - 10.0.0.191
  vpc_reserved_cidr      = "10.0.0.192/26" # 10.0.0.192 - 10.0.0.255 (reserved, not deployed)

  # Shared Services VPC's single /26 is split into two /27s: one for the
  # CE's SLO (outside) interface, one for its SLI (inside) interface.
  shared_svcs_slo_subnet_cidr = "10.0.0.128/27" # 10.0.0.128 - 10.0.0.159
  shared_svcs_sli_subnet_cidr = "10.0.0.160/27" # 10.0.0.160 - 10.0.0.191

  # ---------------------------------------------------------------------------
  # On-prem-mimic VPC: carries BOTH a Class B and a Class C private range,
  # to simulate an on-prem site advertising two disjoint internal networks
  # over the TGW. The Class B range is intentionally much larger than what
  # we actually subnet out of it (172.16.0.0/16 associated at the VPC
  # level, but only a /24 is carved into an actual subnet) - this mirrors
  # how real on-prem sites often advertise a big supernet while only a
  # portion of it is actually routed/populated.
  # ---------------------------------------------------------------------------
  onprem_classb_vpc_cidr    = "172.16.0.0/16"
  onprem_classb_subnet_cidr = "172.16.0.0/24"
  onprem_classc_cidr        = "192.168.50.0/24" # used as both the VPC secondary CIDR and the subnet itself

  # All CIDRs that must be reachable from / route through the Shared
  # Services CE's SLI (inside) interface - i.e. everything on the "spoke"
  # side of the Transit Gateway.
  workload_cidrs = [
    local.vpc_client_a_cidr,
    local.vpc_client_b_cidr,
    local.onprem_classb_subnet_cidr,
    local.onprem_classc_cidr,
  ]

  common_tags = {
    Project     = var.project_name
    Environment = "single"
    ManagedBy   = "terraform"
  }
}
