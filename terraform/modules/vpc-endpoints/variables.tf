variable "name" {
  type        = string
  description = "Name prefix for endpoint resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR — used for interface endpoint SG ingress"
}

variable "aws_region" {
  type        = string
  description = "AWS region for com.amazonaws.<region>.<service> names"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for interface endpoints"
  default     = []
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route table IDs for gateway endpoints (private RTs)"
  default     = []
}

variable "enable_gateway_endpoints" {
  type        = bool
  description = "Create free Gateway endpoints (S3 / DynamoDB)"
  default     = true
}

variable "gateway_services" {
  type        = set(string)
  description = "Gateway endpoint services (no interface hourly fee)"
  default     = ["s3"]
}

variable "enable_interface_endpoints" {
  type        = bool
  description = "Create Interface endpoints (costs money — off by default)"
  default     = false
}

variable "interface_services" {
  type        = list(string)
  description = <<-EOT
    Interface endpoint service short names, e.g.:
    ec2, ecr.api, ecr.dkr, logs, ssm, ssmmessages, ec2messages, sts, kms
  EOT
  default     = []
}

variable "private_dns_enabled" {
  type        = bool
  description = "Enable private DNS on interface endpoints"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}
