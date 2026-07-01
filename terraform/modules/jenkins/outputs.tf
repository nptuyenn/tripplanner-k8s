output "master_instance_id" {
  description = "Jenkins Master EC2 instance ID."
  value       = aws_instance.master.id
}

output "worker_instance_id" {
  description = "Jenkins Worker EC2 instance ID."
  value       = aws_instance.worker.id
}

output "master_public_ip" {
  description = "Stable public IP assigned to Jenkins Master."
  value       = aws_eip.master.public_ip
}

output "worker_public_ip" {
  description = "Stable public IP assigned to Jenkins Worker."
  value       = aws_eip.worker.public_ip
}

output "master_private_ip" {
  description = "Private IP assigned to Jenkins Master."
  value       = aws_instance.master.private_ip
}

output "worker_private_ip" {
  description = "Private IP assigned to Jenkins Worker."
  value       = aws_instance.worker.private_ip
}

