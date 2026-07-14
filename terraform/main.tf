# ─── Network: default VPC (current lab) OR custom VPC module ──────────────────

data "aws_vpc" "default" {
  count   = var.use_custom_vpc ? 0 : 1
  default = true
}

data "aws_subnets" "default" {
  count = var.use_custom_vpc ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

module "vpc" {
  count  = var.use_custom_vpc ? 1 : 0
  source = "./modules/vpc"

  name                   = var.project_name
  vpc_cidr               = var.vpc_cidr
  az_count               = var.vpc_az_count
  availability_zones     = var.vpc_availability_zones
  enable_nat             = var.enable_nat_gateway
  map_public_ip_on_launch = true
  tags                   = local.common_tags
}

module "vpc_endpoints" {
  count  = var.use_custom_vpc && local.create_vpc_endpoints ? 1 : 0
  source = "./modules/vpc-endpoints"

  name       = var.project_name
  vpc_id     = module.vpc[0].vpc_id
  vpc_cidr   = module.vpc[0].vpc_cidr
  aws_region = var.aws_region
  subnet_ids = module.vpc[0].private_subnet_ids
  route_table_ids = concat(
    [module.vpc[0].public_route_table_id],
    module.vpc[0].private_route_table_ids
  )

  enable_gateway_endpoints   = local.enable_gateway_endpoints
  gateway_services           = var.vpc_endpoint_gateway_services
  enable_interface_endpoints = length(local.interface_endpoint_services) > 0
  interface_services         = local.interface_endpoint_services

  tags = local.common_tags
}

# ─── IAM for SSM Session Manager (no bastion / no public SSH required) ────────

module "iam_ssm" {
  count  = var.enable_ssm ? 1 : 0
  source = "./modules/iam-ssm"

  name = var.project_name
  tags = local.common_tags
}

# ─── Security groups (existing module) ────────────────────────────────────────

module "security_groups" {
  source   = "./modules/security-group"
  for_each = var.security_groups

  name        = coalesce(each.value.name, "${var.project_name}-${each.key}-sg")
  description = each.value.description
  vpc_id      = local.vpc_id

  ingress_rules = each.value.ingress_rules
  egress_rules  = each.value.egress_rules

  tags = merge(local.common_tags, {
    SecurityGroupRole = each.key
  })
}

# ─── EC2 nodes — wait for VPC routing, SGs, IAM, SSM endpoints ────────────────

module "nodes" {
  source   = "./modules/ec2"
  for_each = var.instances

  name          = each.value.name
  ami_id        = var.ami_id
  instance_type = coalesce(each.value.instance_type, var.instance_type)
  key_name      = var.key_pair_name

  subnet_id = local.instance_subnet_ids[each.key]

  security_group_ids          = local.instance_security_group_ids[each.key]
  associate_public_ip_address = local.instance_public_ip[each.key]
  iam_instance_profile        = var.enable_ssm ? module.iam_ssm[0].instance_profile_name : null
  user_data_base64            = var.enable_ssm && var.install_ssm_agent ? local.ssm_user_data_base64 : null

  root_volume_size = coalesce(each.value.root_volume_size, var.root_volume_size)
  root_volume_type = coalesce(each.value.root_volume_type, var.root_volume_type)

  tags = local.common_tags
  instance_tags = {
    Role    = each.key
    Ansible = "true"
  }

  # Implicit subnet_id alone does NOT wait for NAT/routes. Force full network readiness.
  depends_on = [
    module.vpc,
    module.vpc_endpoints,
    module.iam_ssm,
    module.security_groups,
  ]
}

# ─── Elastic IP for Nginx edge (only when nginx instance exists) ─────────────

resource "aws_eip" "nginx" {
  count  = contains(keys(var.instances), "nginx") ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nginx-eip"
  })

  # VPC EIPs should wait for IGW (inside vpc module when custom VPC is on)
  depends_on = [module.vpc]
}

resource "aws_eip_association" "nginx" {
  count = contains(keys(var.instances), "nginx") ? 1 : 0

  instance_id   = module.nodes["nginx"].instance_id
  allocation_id = aws_eip.nginx[0].id
}
