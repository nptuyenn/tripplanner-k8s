variable "aws_region" {
  description = "AWS region that stores the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used to build the default globally unique bucket name."
  type        = string
  default     = "tripplanner"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must contain 3-32 lowercase letters, numbers, or hyphens."
  }
}

variable "state_bucket_name" {
  description = "Optional explicit S3 bucket name. When null, a name is generated from project, account ID, and region."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.state_bucket_name == null
      || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    )
    error_message = "state_bucket_name must be null or a valid lowercase S3 bucket name."
  }
}

variable "additional_tags" {
  description = "Additional tags applied to bootstrap resources."
  type        = map(string)
  default     = {}
}

