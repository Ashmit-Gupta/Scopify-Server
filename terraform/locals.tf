locals {
  common_tags = {
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }

  instance_keys  = keys(var.instances)
  public_subnets = data.aws_subnets.default.ids

  # Resolve security group keys on each instance → module output IDs
  instance_security_group_ids = {
    for instance_key, instance in var.instances :
    instance_key => [
      for sg_key in instance.security_group_keys :
      module.security_groups[sg_key].security_group_id
    ]
  }
}
