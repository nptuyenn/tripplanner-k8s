locals {
  cluster_name = "${local.name_prefix}-eks"
}

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "iam" {
  source = "../../modules/iam"

  name_prefix  = local.name_prefix
  cluster_name = local.cluster_name
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix                      = local.name_prefix
  vpc_id                           = module.network.vpc_id
  vpc_cidr                         = module.network.vpc_cidr
  cloudfront_origin_prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
  admin_cidrs                      = var.admin_cidrs
}

module "jenkins" {
  source = "../../modules/jenkins"

  name_prefix                  = local.name_prefix
  ami_id                       = data.aws_ssm_parameter.al2023_ami.value
  instance_type                = var.jenkins_instance_type
  root_volume_size             = var.jenkins_root_volume_size
  master_subnet_id             = module.network.public_subnet_ids[0]
  worker_subnet_id             = module.network.public_subnet_ids[1]
  master_security_group_id     = module.security_groups.jenkins_master_security_group_id
  worker_security_group_id     = module.security_groups.jenkins_worker_security_group_id
  master_instance_profile_name = module.iam.jenkins_master_instance_profile_name
  worker_instance_profile_name = module.iam.jenkins_worker_instance_profile_name
  ssh_public_key               = var.ssh_public_key

  depends_on = [
    module.network,
    module.iam,
    module.security_groups,
  ]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                      = local.cluster_name
  cluster_version                   = var.eks_cluster_version
  cluster_role_arn                  = module.iam.eks_cluster_role_arn
  node_role_arn                     = module.iam.eks_node_role_arn
  jenkins_master_role_arn           = module.iam.jenkins_master_role_arn
  jenkins_master_security_group_id  = module.security_groups.jenkins_master_security_group_id
  control_plane_subnet_ids          = module.network.private_subnet_ids
  node_subnet_ids                   = module.network.private_subnet_ids
  additional_node_security_group_id = module.security_groups.eks_nodes_security_group_id
  public_access_cidrs               = var.admin_cidrs
  node_instance_types               = var.eks_node_instance_types
  node_min_size                     = var.eks_node_min_size
  node_desired_size                 = var.eks_node_desired_size
  node_max_size                     = var.eks_node_max_size
  node_root_volume_size             = var.eks_node_root_volume_size
}

module "edge" {
  source = "../../modules/edge"

  name_prefix  = local.name_prefix
  alb_arn      = data.aws_lb.app.arn
  alb_dns_name = data.aws_lb.app.dns_name
}
