output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded EKS cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Primary security group created by EKS."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL exposed by the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "EKS managed node group name."
  value       = aws_eks_node_group.this.node_group_name
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN used by IRSA roles."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "vpc_cni_role_arn" {
  description = "IRSA role ARN used by the VPC CNI add-on."
  value       = aws_iam_role.vpc_cni.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN used by the EBS CSI add-on."
  value       = aws_iam_role.ebs_csi.arn
}

output "addon_versions" {
  description = "EKS managed add-on versions selected for the cluster."
  value = {
    coredns            = aws_eks_addon.coredns.addon_version
    ebs_csi            = aws_eks_addon.ebs_csi.addon_version
    kube_proxy         = aws_eks_addon.kube_proxy.addon_version
    vpc_cni            = aws_eks_addon.vpc_cni.addon_version
  }
}
