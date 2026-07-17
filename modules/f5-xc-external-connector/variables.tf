############################################
# modules/f5xc-external-connector/variables.tf
#
# STUB MODULE - see README.md in this folder
# before use. These variables are written to
# be resource-agnostic so they can be wired
# into whichever F5XC / AWS resource turns
# out to be correct once you confirm current
# schemas.
############################################

variable "connector_name" {
  description = "Name for the F5XC External Connector object."
  type        = string
}

variable "namespace" {
  description = "F5XC namespace for the External Connector object."
  type        = string
  default     = "system"
}

variable "site_name" {
  description = "Name of the Shared Services Secure Mesh Site v2 this connector peers with F5XC's side of the tunnel."
  type        = string
}

variable "transit_gateway_id" {
  description = "ID of the AWS Transit Gateway to peer with."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
