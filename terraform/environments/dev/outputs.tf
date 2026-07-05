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

output "app_alb_security_group_id" {
  description = "Security group used by the internal application load balancer."
  value       = module.security_groups.app_alb_security_group_id
}

output "jenkins_master_instance_id" {
  description = "Jenkins Master EC2 instance ID."
  value       = module.jenkins.master_instance_id
}

output "jenkins_worker_instance_id" {
  description = "Jenkins Worker EC2 instance ID."
  value       = module.jenkins.worker_instance_id
}

output "jenkins_master_public_ip" {
  description = "Stable public IP assigned to Jenkins Master."
  value       = module.jenkins.master_public_ip
}

output "jenkins_worker_public_ip" {
  description = "Stable public IP assigned to Jenkins Worker."
  value       = module.jenkins.worker_public_ip
}

output "jenkins_master_private_ip" {
  description = "Private IP used by the Jenkins Worker to reach the Master."
  value       = module.jenkins.master_private_ip
}

output "jenkins_worker_private_ip" {
  description = "Private IP assigned to the Jenkins Worker."
  value       = module.jenkins.worker_private_ip
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL used by the next IRSA step."
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_node_group_name" {
  description = "EKS managed node group name."
  value       = module.eks.node_group_name
}

output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN used by EKS service accounts."
  value       = module.eks.oidc_provider_arn
}

output "eks_vpc_cni_role_arn" {
  description = "IRSA role ARN used by the VPC CNI add-on."
  value       = module.eks.vpc_cni_role_arn
}

output "eks_ebs_csi_role_arn" {
  description = "IRSA role ARN used by the EBS CSI add-on."
  value       = module.eks.ebs_csi_role_arn
}

output "eks_load_balancer_controller_role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller."
  value       = module.eks.load_balancer_controller_role_arn
}

output "eks_addon_versions" {
  description = "Managed add-on versions installed in the EKS cluster."
  value       = module.eks.addon_versions
}

output "kubeconfig_command" {
  description = "Command to configure kubectl from Jenkins Master."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "jenkins_master_ssm_command" {
  description = "Command to open an SSM session to Jenkins Master."
  value       = "aws ssm start-session --target ${module.jenkins.master_instance_id} --region ${var.aws_region}"
}

output "jenkins_worker_ssm_command" {
  description = "Command to open an SSM session to Jenkins Worker."
  value       = "aws ssm start-session --target ${module.jenkins.worker_instance_id} --region ${var.aws_region}"
}

output "jenkins_url" {
  description = "URL of the Jenkins service."
  value       = "http://${module.jenkins.master_public_ip}:8080"
}

output "sonarqube_url" {
  description = "URL of the SonarQube service."
  value       = "http://${module.jenkins.master_public_ip}:9000"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for the public TripPlanner endpoint."
  value       = module.edge.distribution_id
}

output "cloudfront_vpc_origin_id" {
  description = "CloudFront VPC origin ID connected to the internal application load balancer."
  value       = module.edge.vpc_origin_id
}

output "tripplanner_public_url" {
  description = "Public HTTPS URL for TripPlanner."
  value       = module.edge.distribution_url
}
