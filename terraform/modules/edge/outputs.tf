output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.app.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.app.domain_name
}

output "distribution_url" {
  description = "Public HTTPS URL for TripPlanner."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "vpc_origin_id" {
  description = "CloudFront VPC origin ID."
  value       = aws_cloudfront_vpc_origin.app.id
}
