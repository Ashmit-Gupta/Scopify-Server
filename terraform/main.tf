# ─── Default VPC ───────────────────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ─── Security groups (one module per entry in var.security_groups) ──────────────
# Customize ports per SG by passing a different ingress_rules list to each key.

module "security_groups" {
  source   = "./modules/security-group"
  for_each = var.security_groups

  name        = coalesce(each.value.name, "${var.project_name}-${each.key}-sg")
  description = each.value.description
  vpc_id      = data.aws_vpc.default.id

  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  tags = merge(local.common_tags, {
    SecurityGroupRole = each.key
  })
}

# ─── EC2 nodes (one module per entry in var.instances) ────────────────────────
# Attach one or more SGs via security_group_keys (e.g. ["cluster"] or ["cluster", "admin"]).

module "nodes" {
  source   = "./modules/ec2"
  for_each = var.instances

  name          = each.value.name
  ami_id        = var.ami_id
  instance_type = coalesce(each.value.instance_type, var.instance_type)
  key_name      = var.key_pair_name

  subnet_id = local.public_subnets[
    index(local.instance_keys, each.key) % length(local.public_subnets)
  ]

  security_group_ids      = local.instance_security_group_ids[each.key]
  associate_public_ip_address = coalesce(each.value.associate_public_ip, true)

  root_volume_size = coalesce(each.value.root_volume_size, var.root_volume_size)
  root_volume_type = coalesce(each.value.root_volume_type, var.root_volume_type)

  tags = local.common_tags
  instance_tags = {
    Role    = each.key
    Ansible = "true"
  }
}
