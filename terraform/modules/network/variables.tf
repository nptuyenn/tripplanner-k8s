variable "name_prefix" {
  description = "Prefix used for network resource names."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used by Kubernetes subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by public and private subnets."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks assigned to public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks assigned to private subnets."
  type        = list(string)
}

