variable "name_prefix" {
  description = "Prefix used for Jenkins EC2 resource names."
  type        = string
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used by Jenkins Master and Worker."
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
}

variable "master_subnet_id" {
  description = "Public subnet ID used by Jenkins Master."
  type        = string
}

variable "worker_subnet_id" {
  description = "Public subnet ID used by Jenkins Worker."
  type        = string
}

variable "master_security_group_id" {
  description = "Security group ID used by Jenkins Master."
  type        = string
}

variable "worker_security_group_id" {
  description = "Security group ID used by Jenkins Worker."
  type        = string
}

variable "master_instance_profile_name" {
  description = "IAM instance profile name used by Jenkins Master."
  type        = string
}

variable "worker_instance_profile_name" {
  description = "IAM instance profile name used by Jenkins Worker."
  type        = string
}

variable "ssh_public_key" {
  description = "Optional OpenSSH public key. SSM remains available when this is null."
  type        = string
  default     = null
  nullable    = true
}

