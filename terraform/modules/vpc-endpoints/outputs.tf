output "gateway_endpoint_ids" {
  description = "Map of gateway service → endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.gateway : k => v.id }
}

output "interface_endpoint_ids" {
  description = "Map of interface service → endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "endpoints_security_group_id" {
  description = "SG used by interface endpoints (null if none)"
  value       = try(aws_security_group.endpoints[0].id, null)
}
