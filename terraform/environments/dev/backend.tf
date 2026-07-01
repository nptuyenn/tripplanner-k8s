terraform {
  backend "s3" {
    bucket       = "tripplanner-tfstate-874587839895-us-east-1"
    key          = "tripplanner/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

