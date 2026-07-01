variable "name_prefix" {
  description = "Prefix used for security group names."
  type        = string
}

variable "vpc_id" {
  description = "VPC that contains the security groups."
  type        = string
}

variable "admin_cidrs" {
  description = "Trusted IPv4 CIDRs allowed to access administration ports."
  type        = set(string)
  default     = []
}

