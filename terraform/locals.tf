locals {
  common_tags = {
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }

  instance_keys = keys(var.instances)

  # Active VPC / subnets depending on mode
  vpc_id = var.use_custom_vpc ? module.vpc[0].vpc_id : data.aws_vpc.default[0].id

  public_subnet_ids = var.use_custom_vpc ? module.vpc[0].public_subnet_ids : data.aws_subnets.default[0].ids

  private_subnet_ids = var.use_custom_vpc ? module.vpc[0].private_subnet_ids : data.aws_subnets.default[0].ids

  # Per-instance subnet: tier public|private (custom VPC) or round-robin default subnets
  instance_subnet_ids = {
    for instance_key, instance in var.instances :
    instance_key => (
      var.use_custom_vpc
      ? (
        coalesce(instance.subnet_tier, "private") == "public"
        ? local.public_subnet_ids[index(local.instance_keys, instance_key) % length(local.public_subnet_ids)]
        : local.private_subnet_ids[index(local.instance_keys, instance_key) % length(local.private_subnet_ids)]
      )
      : local.public_subnet_ids[index(local.instance_keys, instance_key) % length(local.public_subnet_ids)]
    )
  }

  # Public IP: custom VPC private tier => false unless explicitly overridden
  instance_public_ip = {
    for instance_key, instance in var.instances :
    instance_key => (
      instance.associate_public_ip != null
      ? instance.associate_public_ip
      : (
        var.use_custom_vpc
        ? coalesce(instance.subnet_tier, "private") == "public"
        : true
      )
    )
  }

  instance_security_group_ids = {
    for instance_key, instance in var.instances :
    instance_key => [
      for sg_key in instance.security_group_keys :
      module.security_groups[sg_key].security_group_id
    ]
  }

  # Ubuntu cloud-init: install + start Amazon SSM Agent (needed for Session Manager)
  ssm_user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - snapd
    runcmd:
      - snap install amazon-ssm-agent --classic
      - systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
      - systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
  EOF

  ssm_user_data_base64 = base64encode(local.ssm_user_data)

  # VPC endpoints: general flag and/or dedicated SSM endpoints
  ssm_interface_services = ["ssm", "ssmmessages", "ec2messages"]

  create_vpc_endpoints = var.enable_vpc_endpoints || var.enable_ssm_vpc_endpoints

  enable_gateway_endpoints = var.enable_vpc_endpoints && var.vpc_endpoint_gateway_enabled

  interface_endpoint_services = distinct(concat(
    var.enable_ssm_vpc_endpoints ? local.ssm_interface_services : [],
    var.enable_vpc_endpoints && var.vpc_endpoint_interface_enabled ? var.vpc_endpoint_interface_services : []
  ))
}
