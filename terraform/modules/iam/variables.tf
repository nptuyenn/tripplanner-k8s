variable "name_prefix" {
  description = "Prefix used for IAM role and instance profile names."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name Jenkins is allowed to discover."
  type        = string
}

