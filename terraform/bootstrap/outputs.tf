output "state_bucket_name" {
  description = "S3 bucket to use for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_region" {
  description = "AWS region for the S3 backend."
  value       = var.aws_region
}

output "dev_state_key" {
  description = "Recommended state key for the development environment."
  value       = "${var.project_name}/dev/terraform.tfstate"
}

