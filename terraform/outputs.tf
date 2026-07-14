# ─── Network ─────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "Active VPC ID (custom or default)"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "Active VPC CIDR block"
  value       = var.use_custom_vpc ? module.vpc[0].vpc_cidr : data.aws_vpc.default[0].cidr_block
}

output "use_custom_vpc" {
  description = "Whether custom VPC module is active"
  value       = var.use_custom_vpc
}

output "public_subnet_ids" {
  description = "Public subnet IDs (custom VPC) or default VPC subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs when custom VPC enabled; else same as public/default"
  value       = local.private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (custom VPC only)"
  value       = try(module.vpc[0].nat_gateway_id, null)
}

output "nat_eip" {
  description = "NAT Elastic IP (custom VPC only)"
  value       = try(module.vpc[0].nat_eip, null)
}

output "nginx_eip" {
  description = "Elastic IP for Nginx edge (when nginx instance exists)"
  value       = try(aws_eip.nginx[0].public_ip, null)
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs when endpoints module is enabled"
  value = local.create_vpc_endpoints && var.use_custom_vpc ? {
    gateway   = try(module.vpc_endpoints[0].gateway_endpoint_ids, {})
    interface = try(module.vpc_endpoints[0].interface_endpoint_ids, {})
  } : null
}

output "ssm_instance_profile" {
  description = "IAM instance profile name used for SSM (null if enable_ssm = false)"
  value       = try(module.iam_ssm[0].instance_profile_name, null)
}

output "ssm_connect_hint" {
  description = "Example Session Manager commands per instance"
  value = var.enable_ssm ? {
    for k, v in module.nodes :
    k => "aws ssm start-session --target ${v.instance_id} --region ${var.aws_region}"
  } : null
}

output "security_group_ids" {
  description = "Map of security group key → ID"
  value       = { for k, v in module.security_groups : k => v.security_group_id }
}

output "security_group_names" {
  description = "Map of security group key → name"
  value       = { for k, v in module.security_groups : k => v.security_group_name }
}

output "security_group_id" {
  description = "Cluster security group ID (key: cluster)"
  value       = try(module.security_groups["cluster"].security_group_id, null)
}

output "security_group_name" {
  description = "Cluster security group name (key: cluster)"
  value       = try(module.security_groups["cluster"].security_group_name, null)
}

# ─── Per-node maps ───────────────────────────────────────────────────────────

output "instance_ids" {
  description = "Map of instance key → EC2 instance ID"
  value       = { for k, v in module.nodes : k => v.instance_id }
}

output "instance_names" {
  description = "Map of instance key → Name tag"
  value       = { for k, v in module.nodes : k => v.name }
}

output "instance_public_ips" {
  description = "Map of instance key → public IP"
  value       = { for k, v in module.nodes : k => v.public_ip }
}

output "instance_private_ips" {
  description = "Map of instance key → private IP"
  value       = { for k, v in module.nodes : k => v.private_ip }
}

output "instance_public_dns" {
  description = "Map of instance key → public DNS"
  value       = { for k, v in module.nodes : k => v.public_dns }
}

output "instance_availability_zones" {
  description = "Map of instance key → availability zone"
  value       = { for k, v in module.nodes : k => v.availability_zone }
}

output "instance_subnet_ids" {
  description = "Map of instance key → subnet ID"
  value       = { for k, v in module.nodes : k => v.subnet_id }
}

output "ssh_commands" {
  description = "Map of instance key → SSH command (ubuntu user)"
  value = {
    for k, v in module.nodes :
    k => "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${v.public_ip}"
  }
}

output "master_public_ip" {
  description = "Public IP of the Master node"
  value       = try(module.nodes["master"].public_ip, null)
}

output "master_private_ip" {
  description = "Private IP of the Master node"
  value       = try(module.nodes["master"].private_ip, null)
}

output "master_ssh_command" {
  description = "SSH command for the Master node"
  value       = try("ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.nodes["master"].public_ip}", null)
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes only"
  value = {
    for k, v in module.nodes :
    k => v.public_ip if startswith(k, "worker")
  }
}

output "tools_public_ips" {
  description = "Public IPs of Jenkins / Sonar / Nexus VMs"
  value = {
    for k, v in module.nodes :
    k => v.public_ip if contains(["jenkins", "sonar", "nexus"], k)
  }
}

output "tools_urls" {
  description = "HTTP URLs for CI/CD tools (after Ansible site-tools.yml)"
  value = {
    jenkins = try("http://${module.nodes["jenkins"].public_ip}:8080", null)
    sonar   = try("http://${module.nodes["sonar"].public_ip}:9000", null)
    nexus   = try("http://${module.nodes["nexus"].public_ip}:8081", null)
  }
}

output "nodes" {
  description = "All node details in one map — use for scripts and Ansible inventory"
  value = {
    for k, v in module.nodes : k => {
      name              = v.name
      role              = k
      instance_id       = v.instance_id
      instance_type     = v.instance_type
      ami               = v.ami
      availability_zone = v.availability_zone
      subnet_id         = v.subnet_id
      public_ip         = v.public_ip
      private_ip        = v.private_ip
      public_dns        = v.public_dns
      private_dns       = v.private_dns
      ssh_command       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${v.public_ip}"
    }
  }
}

output "cluster_summary" {
  description = "Formatted summary with IPs and SSH commands — print after apply"
  value = join("\n", concat(
    [
      "══════════════════════════════════════════════════════════════════",
      "  CLUSTER SUMMARY",
      "══════════════════════════════════════════════════════════════════",
      "  Project:         ${var.project_name}",
      "  Environment:     ${var.environment}",
      "  Region:          ${var.aws_region}",
      "  Instance type:   ${var.instance_type}",
      "  Key pair:        ${var.key_pair_name}",
      "──────────────────────────────────────────────────────────────────",
      "  VPC mode:        ${var.use_custom_vpc ? "custom" : "default"}",
      "  VPC ID:          ${local.vpc_id}",
      "  Public subnets:  ${join(", ", local.public_subnet_ids)}",
      "  Private subnets: ${join(", ", local.private_subnet_ids)}",
      "  Nginx EIP:       ${try(aws_eip.nginx[0].public_ip, "n/a")}",
      "  Security groups: ${join(", ", [for k, v in module.security_groups : "${k}=${v.security_group_id}"])}",
      "──────────────────────────────────────────────────────────────────",
      "  NODES",
    ],
    [
      for k, v in module.nodes :
      format(
        "  %-10s  Name: %-10s  Public: %-15s  Private: %-15s  AZ: %s\n              ID: %s\n              SSH: ssh -i ~/.ssh/%s.pem ubuntu@%s",
        k,
        v.name,
        v.public_ip,
        v.private_ip,
        v.availability_zone,
        v.instance_id,
        var.key_pair_name,
        v.public_ip
      )
    ],
    [
      "══════════════════════════════════════════════════════════════════",
    ]
  ))
}
