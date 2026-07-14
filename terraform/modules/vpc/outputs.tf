output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ordered by AZ index)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ordered by AZ index)"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (null if enable_nat = false)"
  value       = try(aws_nat_gateway.this[0].id, null)
}

output "nat_eip" {
  description = "NAT Elastic IP (null if enable_nat = false)"
  value       = try(aws_eip.nat[0].public_ip, null)
}

output "availability_zones" {
  description = "AZs used for subnets"
  value       = local.azs
}

# Referenced by root depends_on so EC2 waits for NAT + routes, not only subnet IDs
output "network_ready" {
  description = "Stable token after routing is fully associated"
  value = md5(join(",", concat(
    aws_route_table_association.public[*].id,
    aws_route_table_association.private[*].id,
    var.enable_nat ? [aws_nat_gateway.this[0].id] : []
  )))
}
