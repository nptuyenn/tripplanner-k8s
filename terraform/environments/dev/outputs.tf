output "aws_account_id" {
  description = "AWS account used by the development environment."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by the development environment."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Prefix used for development resource names."
  value       = local.name_prefix
}

