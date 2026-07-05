variable "name_prefix" {
  description = "Prefix used for security group names."
  type        = string
}

variable "vpc_id" {
  description = "VPC that contains the security groups."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC used to restrict application load balancer egress."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "cloudfront_origin_prefix_list_id" {
  description = "AWS-managed CloudFront origin-facing prefix list allowed to reach the application load balancer."
  type        = string

  validation {
    condition     = can(regex("^pl-[0-9a-f]+$", var.cloudfront_origin_prefix_list_id))
    error_message = "cloudfront_origin_prefix_list_id must be a valid managed prefix list ID."
  }
}

variable "admin_cidrs" {
  description = "Trusted IPv4 CIDRs allowed to access administration ports."
  type        = set(string)
  default     = []
}

