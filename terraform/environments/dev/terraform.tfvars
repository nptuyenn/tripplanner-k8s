aws_region              = "us-east-1"
expected_aws_account_id = "874587839895"
project_name            = "tripplanner"
environment             = "dev"
owner                   = "nptuyenn"

additional_tags = {
  Repository = "tripplanner-k8s"
}

vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24",
]

# Add your current public IP as a /32 before creating Jenkins EC2 instances.
admin_cidrs = []

# Leave null to use AWS Systems Manager Session Manager instead of SSH.
ssh_public_key = null

jenkins_instance_type    = "t3.large"
jenkins_root_volume_size = 30

eks_cluster_version       = "1.35"
eks_node_instance_types   = ["t3.large"]
eks_node_min_size         = 2
eks_node_desired_size     = 2
eks_node_max_size         = 3
eks_node_root_volume_size = 30
