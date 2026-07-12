# ─── Network ─────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "Default VPC ID"
  value       = data.aws_vpc.default.id
}

output "vpc_cidr" {
  description = "Default VPC CIDR block"
  value       = data.aws_vpc.default.cidr_block
}

output "public_subnet_ids" {
  description = "Subnet IDs used in the default VPC"
  value       = data.aws_subnets.default.ids
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
      "  VPC ID:          ${data.aws_vpc.default.id}",
      "  VPC CIDR:        ${data.aws_vpc.default.cidr_block}",
      "  Subnets:         ${join(", ", data.aws_subnets.default.ids)}",
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
