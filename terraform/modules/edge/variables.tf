variable "name_prefix" {
  description = "Prefix used for CloudFront resource names."
  type        = string
}

variable "alb_arn" {
  description = "ARN of the internal application load balancer used as the VPC origin."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:loadbalancer/app/", var.alb_arn))
    error_message = "alb_arn must be an Application Load Balancer ARN."
  }
}

variable "alb_dns_name" {
  description = "DNS name of the internal application load balancer."
  type        = string

  validation {
    condition     = length(trimspace(var.alb_dns_name)) > 0
    error_message = "alb_dns_name must not be empty."
  }
}
