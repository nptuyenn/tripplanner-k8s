output "vpc_id" {
  description = "ID of the TripPlanner VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the TripPlanner VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs ordered by their input position."
  value       = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs ordered by their input position."
  value       = [for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id]
}

output "nat_gateway_public_ip" {
  description = "Public egress IP used by workloads in private subnets."
  value       = aws_eip.nat.public_ip
}

