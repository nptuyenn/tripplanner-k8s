resource "aws_security_group" "jenkins_master" {
  name        = "${var.name_prefix}-jenkins-master"
  description = "Access to Jenkins Master and SonarQube"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-jenkins-master"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_master_ssh" {
  for_each = var.admin_cidrs

  security_group_id = aws_security_group.jenkins_master.id
  description       = "SSH from a trusted administrator address"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui" {
  for_each = var.admin_cidrs

  security_group_id = aws_security_group.jenkins_master.id
  description       = "Jenkins UI from a trusted administrator address"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_ui" {
  for_each = var.admin_cidrs

  security_group_id = aws_security_group.jenkins_master.id
  description       = "SonarQube UI from a trusted administrator address"
  cidr_ipv4         = each.value
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_from_worker" {
  security_group_id            = aws_security_group.jenkins_master.id
  description                  = "Jenkins WebSocket agent connection from the Worker"
  referenced_security_group_id = aws_security_group.jenkins_worker.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_from_worker" {
  security_group_id            = aws_security_group.jenkins_master.id
  description                  = "SonarQube analysis traffic from the Worker"
  referenced_security_group_id = aws_security_group.jenkins_worker.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_master" {
  security_group_id = aws_security_group.jenkins_master.id
  description       = "Outbound access for package installation and managed services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "jenkins_worker" {
  name        = "${var.name_prefix}-jenkins-worker"
  description = "Access to the Jenkins Worker"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-jenkins-worker"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_worker_admin_ssh" {
  for_each = var.admin_cidrs

  security_group_id = aws_security_group.jenkins_worker.id
  description       = "SSH from a trusted administrator address"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_worker" {
  security_group_id = aws_security_group.jenkins_worker.id
  description       = "Outbound access for builds and managed services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name_prefix}-eks-nodes-additional"
  description = "Additional administrator access to EKS NodePorts"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-eks-nodes-additional"
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodeports" {
  for_each = var.admin_cidrs

  security_group_id = aws_security_group.eks_nodes.id
  description       = "Kubernetes NodePorts from a trusted administrator address"
  cidr_ipv4         = each.value
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "eks_nodes" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Outbound access for cluster nodes"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

