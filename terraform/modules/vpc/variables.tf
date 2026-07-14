variable "name" {
  type        = string
  description = "Name prefix for VPC resources (e.g. scopify-cluster)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.20.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of AZs for public + private subnet pairs"
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Optional explicit AZ names; empty = first az_count from the region"
  default     = []
}

variable "subnet_newbits" {
  type        = number
  description = "Additional prefix bits for subnet CIDRs (vpc /16 + 4 => /20)"
  default     = 4
}

variable "enable_nat" {
  type        = bool
  description = "Create NAT Gateway + EIP so private subnets can reach the internet (~$32+/mo)"
  default     = true
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "Auto-assign public IPs in public subnets"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags merged onto all VPC resources"
  default     = {}
}
