locals {
  # Root passes egress_rules = null when omitted in tfvars (bypasses variable default).
  # Use concat() for the fallback so Terraform gets list(object), not tuple.
  default_egress_rules = concat([], [
    {
      description               = "Allow all outbound"
      from_port                 = 0
      to_port                   = 0
      protocol                  = "-1"
      cidr_blocks               = ["0.0.0.0/0"]
      ipv6_cidr_blocks          = null
      source_security_group_ids = null
      self                      = null
    }
  ])

  egress_rules = var.egress_rules != null ? var.egress_rules : local.default_egress_rules
}

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      security_groups  = ingress.value.source_security_group_ids
      self             = ingress.value.self
    }
  }

  dynamic "egress" {
    for_each = local.egress_rules
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      security_groups  = egress.value.source_security_group_ids
      self             = egress.value.self
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}
