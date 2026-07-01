output "aws_account_id" {
  description = "AWS account used by the development environment."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by the development environment."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Prefix used for development resource names."
  value       = local.name_prefix
}

output "vpc_id" {
  description = "ID of the TripPlanner development VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by Jenkins EC2 instances."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS managed nodes."
  value       = module.network.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Stable public egress IP for private EKS nodes and Atlas allowlisting."
  value       = module.network.nat_gateway_public_ip
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN prepared for the EKS control plane."
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN prepared for the EKS managed node group."
  value       = module.iam.eks_node_role_arn
}

output "jenkins_master_security_group_id" {
  description = "Security group prepared for Jenkins Master."
  value       = module.security_groups.jenkins_master_security_group_id
}

output "jenkins_worker_security_group_id" {
  description = "Security group prepared for Jenkins Worker."
  value       = module.security_groups.jenkins_worker_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "Additional security group prepared for EKS NodePorts."
  value       = module.security_groups.eks_nodes_security_group_id
}
