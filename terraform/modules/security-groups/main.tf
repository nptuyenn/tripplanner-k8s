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

resource "aws_security_group" "app_alb" {
  name        = "${var.name_prefix}-app-alb"
  description = "Private entry point for the TripPlanner frontend"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-app-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_alb_from_cloudfront" {
  security_group_id = aws_security_group.app_alb.id
  description       = "HTTP from the AWS-managed CloudFront origin-facing prefix list"
  prefix_list_id    = var.cloudfront_origin_prefix_list_id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_alb_from_jenkins_master" {
  security_group_id            = aws_security_group.app_alb.id
  description                  = "HTTP smoke tests from Jenkins Master"
  referenced_security_group_id = aws_security_group.jenkins_master.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_alb_to_frontend" {
  security_group_id = aws_security_group.app_alb.id
  description       = "HTTP to frontend pod IPs inside the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "eks_frontend_from_app_alb" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "Frontend pod traffic from the application load balancer"
  referenced_security_group_id = aws_security_group.app_alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
