############################################
# modules/client-node/variables.tf
#
# A single Amazon Linux EC2 instance used
# to represent a "client" workload in a
# spoke VPC, or the on-prem-mimic host.
############################################

variable "name" {
  description = "Name for this instance (used for the Name tag and hostname)."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance in."
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance's primary ENI."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type. Defaults to a small burstable type since these are just lab client machines."
  type        = string
  default     = "t3.micro"
}

variable "associate_public_ip" {
  description = "Whether to auto-assign a public IP on the primary ENI (only relevant if the subnet is 'public', i.e. has an IGW route)."
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access. Leave null to rely on SSM Session Manager only."
  type        = string
  default     = null
}

variable "enable_ssm" {
  description = "Attach an IAM instance profile with AmazonSSMManagedInstanceCore so the instance is reachable via AWS Systems Manager Session Manager without needing an open SSH port."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
