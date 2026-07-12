variable "name" {
  type        = string
  description = "Security group name"
}

variable "description" {
  type        = string
  description = "Security group description"
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group is created"
}

variable "ingress_rules" {
  type = list(object({
    description               = optional(string, "")
    from_port                 = number
    to_port                   = number
    protocol                  = string
    cidr_blocks               = optional(list(string))
    ipv6_cidr_blocks          = optional(list(string))
    source_security_group_ids = optional(list(string))
    self                      = optional(bool)
  }))
  description = "Inbound rules — each SG module call can pass a different list"
  default     = []
}

variable "egress_rules" {
  type = list(object({
    description               = optional(string, "")
    from_port                 = number
    to_port                   = number
    protocol                  = string
    cidr_blocks               = optional(list(string))
    ipv6_cidr_blocks          = optional(list(string))
    source_security_group_ids = optional(list(string))
    self                      = optional(bool)
  }))
  description = "Outbound rules — omit or pass null to allow all outbound (see main.tf local)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged onto the security group"
  default     = {}
}
