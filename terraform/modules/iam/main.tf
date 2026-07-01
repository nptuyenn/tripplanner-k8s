data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.name_prefix}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  name               = "${var.name_prefix}-eks-nodes"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

locals {
  node_managed_policies = {
    worker = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    cni    = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
    ecr    = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    ssm    = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each = local.node_managed_policies

  role       = aws_iam_role.eks_nodes.name
  policy_arn = each.value
}

resource "aws_iam_role" "jenkins_master" {
  name               = "${var.name_prefix}-jenkins-master"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role" "jenkins_worker" {
  name               = "${var.name_prefix}-jenkins-worker"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jenkins_master_ssm" {
  role       = aws_iam_role.jenkins_master.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jenkins_worker_ssm" {
  role       = aws_iam_role.jenkins_worker.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jenkins_eks_discovery" {
  statement {
    sid       = "ListClusters"
    effect    = "Allow"
    actions   = ["eks:ListClusters"]
    resources = ["*"]
  }

  statement {
    sid     = "DescribeTripPlannerCluster"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
  }
}

resource "aws_iam_role_policy" "jenkins_master_eks_discovery" {
  name   = "eks-cluster-discovery"
  role   = aws_iam_role.jenkins_master.id
  policy = data.aws_iam_policy_document.jenkins_eks_discovery.json
}

resource "aws_iam_role_policy" "jenkins_worker_eks_discovery" {
  name   = "eks-cluster-discovery"
  role   = aws_iam_role.jenkins_worker.id
  policy = data.aws_iam_policy_document.jenkins_eks_discovery.json
}

resource "aws_iam_instance_profile" "jenkins_master" {
  name = "${var.name_prefix}-jenkins-master"
  role = aws_iam_role.jenkins_master.name
}

resource "aws_iam_instance_profile" "jenkins_worker" {
  name = "${var.name_prefix}-jenkins-worker"
  role = aws_iam_role.jenkins_worker.name
}

