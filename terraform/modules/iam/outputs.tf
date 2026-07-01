output "eks_cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN used by the EKS managed node group."
  value       = aws_iam_role.eks_nodes.arn
}

output "jenkins_master_role_arn" {
  description = "IAM role ARN used by the Jenkins Master EC2 instance."
  value       = aws_iam_role.jenkins_master.arn
}

output "jenkins_worker_role_arn" {
  description = "IAM role ARN used by the Jenkins Worker EC2 instance."
  value       = aws_iam_role.jenkins_worker.arn
}

output "jenkins_master_instance_profile_name" {
  description = "Instance profile attached to Jenkins Master."
  value       = aws_iam_instance_profile.jenkins_master.name
}

output "jenkins_worker_instance_profile_name" {
  description = "Instance profile attached to Jenkins Worker."
  value       = aws_iam_instance_profile.jenkins_worker.name
}

