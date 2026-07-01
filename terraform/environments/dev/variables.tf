variable "aws_region" {
  description = "AWS region used by the development environment."
  type        = string
  default     = "us-east-1"
}

variable "expected_aws_account_id" {
  description = "AWS account allowed to receive TripPlanner resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must contain exactly 12 digits."
  }
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "tripplanner"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must contain 3-32 lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "owner" {
  description = "Owner tag applied to all supported AWS resources."
  type        = string
}

variable "additional_tags" {
  description = "Additional tags merged into the common resource tags."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the development VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to public subnets."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks assigned to private subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Public and private subnet CIDR lists must have the same length."
  }
}

variable "admin_cidrs" {
  description = "Trusted IPv4 CIDRs allowed to reach administration ports."
  type        = set(string)
  default     = []
}

