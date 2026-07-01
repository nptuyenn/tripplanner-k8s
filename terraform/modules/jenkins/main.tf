resource "aws_key_pair" "this" {
  count = var.ssh_public_key == null ? 0 : 1

  key_name   = "${var.name_prefix}-jenkins"
  public_key = var.ssh_public_key
}

resource "aws_instance" "master" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.master_subnet_id
  vpc_security_group_ids      = [var.master_security_group_id]
  iam_instance_profile        = var.master_instance_profile_name
  associate_public_ip_address = true
  key_name                    = var.ssh_public_key == null ? null : aws_key_pair.this[0].key_name
  user_data                   = file("${path.module}/master-user-data.sh")
  user_data_replace_on_change = true
  monitoring                  = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name_prefix}-jenkins-master"
    Role = "jenkins-master"
  }
}

resource "aws_instance" "worker" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.worker_subnet_id
  vpc_security_group_ids      = [var.worker_security_group_id]
  iam_instance_profile        = var.worker_instance_profile_name
  associate_public_ip_address = true
  key_name                    = var.ssh_public_key == null ? null : aws_key_pair.this[0].key_name
  user_data                   = file("${path.module}/worker-user-data.sh")
  user_data_replace_on_change = true
  monitoring                  = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.name_prefix}-jenkins-worker"
    Role = "jenkins-worker"
  }
}

resource "aws_eip" "master" {
  domain   = "vpc"
  instance = aws_instance.master.id

  tags = {
    Name = "${var.name_prefix}-jenkins-master"
  }
}

resource "aws_eip" "worker" {
  domain   = "vpc"
  instance = aws_instance.worker.id

  tags = {
    Name = "${var.name_prefix}-jenkins-worker"
  }
}
