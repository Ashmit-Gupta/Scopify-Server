variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
}

variable "project_name" {
  type        = string
  description = "Project name used in resource naming and tags"
}

variable "environment" {
  type        = string
  description = "Environment label (dev, staging, prod)"
  default     = "dev"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu AMI ID for ap-south-1"
}

variable "instance_type" {
  type        = string
  description = "Default EC2 instance type — c7i-flex.large (2 vCPU, 4 GiB) recommended for Kubernetes"
  default     = "c7i-flex.large"
}

variable "root_volume_size" {
  type        = number
  description = "Default root EBS volume size in GB for each node"
  default     = 25

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 500
    error_message = "root_volume_size must be between 8 and 500 GB."
  }
}

variable "root_volume_type" {
  type        = string
  description = "Default EBS volume type for root disk"
  default     = "gp3"
}

variable "key_pair_name" {
  type        = string
  description = "Existing EC2 key pair name for SSH access"
}

variable "allowed_ingress_cidr" {
  type        = string
  description = "Default CIDR for ingress rules that do not specify cidr_blocks"
  default     = "0.0.0.0/0"
}

variable "security_groups" {
  type = map(object({
    name          = optional(string)
    description   = optional(string, "Managed by Terraform")
    ingress_rules = list(object({
      description               = optional(string, "")
      from_port                 = number
      to_port                   = number
      protocol                  = string
      cidr_blocks               = optional(list(string))
      ipv6_cidr_blocks          = optional(list(string))
      source_security_group_ids = optional(list(string))
      self                      = optional(bool)
    }))
    egress_rules = optional(list(object({
      description               = optional(string, "")
      from_port                 = number
      to_port                   = number
      protocol                  = string
      cidr_blocks               = optional(list(string))
      ipv6_cidr_blocks          = optional(list(string))
      source_security_group_ids = optional(list(string))
      self                      = optional(bool)
    })))
  }))
  description = "Map of security groups — each entry gets its own ingress_rules list"
}

variable "instances" {
  type = map(object({
    name                = string
    security_group_keys = list(string)
    instance_type       = optional(string)
    root_volume_size    = optional(number)
    root_volume_type    = optional(string)
    associate_public_ip = optional(bool)
    subnet_tier         = optional(string) # "public" | "private" — used when use_custom_vpc = true
  }))
  description = "Map of EC2 instances — security_group_keys references keys in var.security_groups"
}

variable "owner" {
  type        = string
  description = "Owner tag value"
  default     = "Ashmit"
}

# ─── Custom VPC (frozen architecture) ─────────────────────────────────────────

variable "use_custom_vpc" {
  type        = bool
  description = "If true, create modules/vpc instead of using the account default VPC. Keep false until ready to migrate the lab."
  default     = false
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for custom VPC"
  default     = "10.20.0.0/16"
}

variable "vpc_az_count" {
  type        = number
  description = "AZ count for public+private subnet pairs"
  default     = 2
}

variable "vpc_availability_zones" {
  type        = list(string)
  description = "Optional explicit AZs; empty = auto"
  default     = []
}

variable "enable_nat_gateway" {
  type        = bool
  description = "NAT Gateway for private subnet outbound (costly; needed for true private tier)"
  default     = true
}

variable "enable_vpc_endpoints" {
  type        = bool
  description = "Create VPC endpoints module. Optional if NAT is on. Required for SSM only if you disable NAT."
  default     = false
}

variable "enable_ssm" {
  type        = bool
  description = "Attach IAM instance profile for AWS Systems Manager Session Manager (recommended with private subnets)"
  default     = true
}

variable "install_ssm_agent" {
  type        = bool
  description = "Inject Ubuntu cloud-init to install amazon-ssm-agent via snap (set false if AMI already has agent)"
  default     = true
}

variable "enable_ssm_vpc_endpoints" {
  type        = bool
  description = <<-EOT
    Create Interface VPC endpoints required for SSM without using the public AWS network:
    ssm, ssmmessages, ec2messages.
    With NAT only, leave this false. With no NAT, set this true or SSM will not work.
  EOT
  default     = false
}

variable "vpc_endpoint_gateway_enabled" {
  type        = bool
  description = "Gateway endpoints (S3 etc.) — cheap, useful with private subnets"
  default     = true
}

variable "vpc_endpoint_gateway_services" {
  type        = set(string)
  description = "Gateway endpoint services"
  default     = ["s3"]
}

variable "vpc_endpoint_interface_enabled" {
  type        = bool
  description = "Interface endpoints (ECR/SSM/…) — hourly cost; leave false unless needed"
  default     = false
}

variable "vpc_endpoint_interface_services" {
  type        = list(string)
  description = "Interface endpoint short names when interface endpoints enabled"
  default     = ["ec2", "ecr.api", "ecr.dkr", "logs", "ssm", "ssmmessages", "ec2messages"]
}
