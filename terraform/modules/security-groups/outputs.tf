output "jenkins_master_security_group_id" {
  description = "Security group ID for Jenkins Master."
  value       = aws_security_group.jenkins_master.id
}

output "jenkins_worker_security_group_id" {
  description = "Security group ID for Jenkins Worker."
  value       = aws_security_group.jenkins_worker.id
}

output "eks_nodes_security_group_id" {
  description = "Additional security group ID for EKS managed nodes."
  value       = aws_security_group.eks_nodes.id
}

