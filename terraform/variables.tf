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
    associate_public_ip = optional(bool, true)
  }))
  description = "Map of EC2 instances — security_group_keys references keys in var.security_groups"
}

variable "owner" {
  type        = string
  description = "Owner tag value"
  default     = "Ashmit"
}
