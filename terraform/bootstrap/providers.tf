provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = "bootstrap"
        ManagedBy   = "Terraform"
      },
      var.additional_tags,
    )
  }
}

