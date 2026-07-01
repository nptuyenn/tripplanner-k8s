variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version used by EKS."
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN used by the EKS managed node group."
  type        = string
}

variable "jenkins_master_role_arn" {
  description = "Jenkins Master IAM role granted cluster administrator access."
  type        = string
}

variable "jenkins_master_security_group_id" {
  description = "Jenkins Master security group allowed to reach the private Kubernetes API."
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs used by EKS control-plane network interfaces."
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Private subnet IDs used by the managed node group."
  type        = list(string)
}

variable "additional_node_security_group_id" {
  description = "Additional security group attached to managed nodes."
  type        = string
}

variable "public_access_cidrs" {
  description = "Trusted CIDRs allowed to reach the public Kubernetes API endpoint."
  type        = set(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types available to the managed node group."
  type        = list(string)
}

variable "node_min_size" {
  description = "Minimum managed node count."
  type        = number
}

variable "node_desired_size" {
  description = "Desired managed node count."
  type        = number
}

variable "node_max_size" {
  description = "Maximum managed node count."
  type        = number
}

variable "node_root_volume_size" {
  description = "Managed node root volume size in GiB."
  type        = number
}
