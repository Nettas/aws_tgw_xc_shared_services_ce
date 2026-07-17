############################################
# environments/single/variables.tf
############################################

# --- General -----------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources. Single-region design per current decision."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Short project identifier used as a prefix/tag across all resources."
  type        = string
  default     = "aws-tgw-xc-sharedservice-ce"
}

variable "mgmt_allowed_cidrs" {
  description = <<-EOT
    CIDR blocks allowed SSH/ICMP/local-UI troubleshooting access to client
    nodes and the F5 CE's SLO interface. Keep this scoped to your own
    workstation or corporate VPN egress IP - do not leave this as
    0.0.0.0/0 outside of a short-lived lab.
  EOT
  type = list(string)
}

variable "ssh_key_name" {
  description = "Optional existing EC2 key pair name for SSH access to client nodes and the CE node. Leave null to rely on SSM Session Manager for client nodes (the CE node has no SSM agent, so set this if you need CE console access via SSH)."
  type        = string
  default     = null
}

# --- F5 Distributed Cloud tenant ----------------------------------------------

variable "f5xc_api_url" {
  description = "F5 Distributed Cloud tenant API URL, e.g. https://<tenant>.console.ves.volterra.io/api"
  type        = string
}

variable "f5xc_api_p12_file" {
  description = "Local filesystem path to the F5XC API client certificate (.p12) used to authenticate the volterra provider. Never commit this file - keep it outside the repo and reference it by absolute path."
  type        = string
  sensitive   = true
}

variable "f5xc_site_name" {
  description = "Name for the Shared Services Secure Mesh Site v2 object (DNS-1035 label: lowercase alphanumeric + hyphens, starts with a letter)."
  type        = string
  default     = "shared-services-ce"
}

variable "f5xc_site_latitude" {
  description = "Approximate latitude for Regional Edge geo-proximity selection. us-east-2 (Columbus, OH) ~ 39.96."
  type        = number
  default     = 39.96
}

variable "f5xc_site_longitude" {
  description = "Approximate longitude for Regional Edge geo-proximity selection. us-east-2 (Columbus, OH) ~ -82.99."
  type        = number
  default     = -82.99
}
