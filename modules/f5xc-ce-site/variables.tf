############################################
# modules/f5xc-ce-site/variables.tf
#
# Deploys a single-node F5 Distributed Cloud
# Secure Mesh Site v2 (SMSv2) Customer Edge
# in AWS, following:
#   https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-to/site-management/deploy-sms-aws-clickops
#
# This uses the Marketplace AMI (via the AWS
# SSM parameter F5 publishes) rather than the
# downloaded .vhd.gz + vmimport path, and is
# a DUAL-INTERFACE node:
#   - SLO (Site Local Outside): egress to the
#     Internet, used for CE <-> F5 Regional
#     Edge control/data tunnels.
#   - SLI (Site Local Inside): faces the
#     Transit Gateway attachment subnet, used
#     to reach/discover workloads in the
#     spoke VPCs and the on-prem-mimic VPC.
#
# IMPORTANT: You must first subscribe to the
# F5 Distributed Cloud CE AMI in AWS
# Marketplace in this account/region before
# `terraform apply` can resolve the AMI via
# SSM - otherwise the data source lookup (or
# the instance launch) will fail with an
# authorization error.
############################################

# --- F5 Distributed Cloud tenant / site identity -----------------------------

variable "site_name" {
  description = "Name of the Secure Mesh Site v2 object in F5 Distributed Cloud Console. Must be lowercase alphanumeric + hyphens, start with a letter (DNS-1035 label)."
  type        = string
}

variable "namespace" {
  description = "F5XC namespace to create the Site and Token objects in. Site objects almost always live in the 'system' namespace."
  type        = string
  default     = "system"
}

variable "latitude" {
  description = "Approximate latitude of the site, used by F5XC for Regional Edge selection (geo-proximity)."
  type        = number
}

variable "longitude" {
  description = "Approximate longitude of the site, used by F5XC for Regional Edge selection (geo-proximity)."
  type        = number
}

# --- AWS placement -------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID of the Shared Services VPC the CE node will be deployed into."
  type        = string
}

variable "slo_subnet_id" {
  description = "Subnet ID for the SLO (outside/Internet-facing) network interface."
  type        = string
}

variable "sli_subnet_id" {
  description = "Subnet ID for the SLI (inside/TGW-facing) network interface."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the CE node. F5 recommends m5.2xlarge as the minimum supported size."
  type        = string
  default     = "m5.2xlarge"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB. F5 minimum is 80 GB."
  type        = number
  default     = 80
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH troubleshooting access to the CE node."
  type        = string
  default     = null
}

variable "marketplace_ami_ssm_parameter" {
  description = <<-EOT
    SSM parameter path that resolves to the latest F5 Distributed Cloud CE
    Marketplace AMI ID. This is the value F5 documents for the AWS
    Marketplace launch path. Verify this is still current for your account
    before first apply, since F5 can roll the parameter path on major
    releases.
  EOT
  type    = string
  default = "/aws/service/marketplace/prod-wrwzhcymymama/latest"
}

# --- Security groups ------------------------------------------------------------

variable "mgmt_allowed_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to reach the CE node's SSH (22) and local UI
    (65500) ports on the SLO interface for troubleshooting. Keep this
    tight (e.g. your own workstation /32 or corporate VPN range) - it is
    NOT required for normal CE operation, which only needs outbound
    connectivity to F5 Regional Edges.
  EOT
  type = list(string)
}

variable "workload_cidrs" {
  description = <<-EOT
    List of CIDR blocks reachable via the Transit Gateway that the CE's
    SLI interface must be able to send/receive traffic to/from (the two
    client VPC CIDRs plus the on-prem-mimic VPC's Class B and Class C
    ranges). Used to scope the SLI security group instead of opening it
    to the entire internet.
  EOT
  type = list(string)
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
