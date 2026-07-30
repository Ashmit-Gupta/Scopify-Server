# Terraform

Infrastructure as Code for the Scopify AWS foundation. Root module: `Scopify Server/terraform/`.

---

## Folder Structure

```
terraform/
├── main.tf                 # Wires modules + Nginx EIP
├── locals.tf               # Tags, subnet selection, SSM userdata, endpoint flags
├── variables.tf
├── outputs.tf
├── providers.tf            # AWS ~> 6.0, Terraform >= 1.5
├── terraform.tfvars        # Live lab values (as-built)
├── terraform.tfvars.example
├── DEPENDENCY_FLOW.md
├── AWS_GAPS.md
├── AWS_ACCESS.md
├── modules/
│   ├── vpc/
│   ├── vpc-endpoints/
│   ├── iam-ssm/
│   ├── security-group/
│   └── ec2/
└── scripts/
```

---

## State Management

| Item | As-built |
|------|----------|
| Backend | **Local** `terraform.tfstate` (present in workspace) |
| Locking | None (local) |
| CI apply | Not configured |

**Why local today:** Solo lab velocity.  
**Risk:** Laptop loss / git accidents / no team collaboration.  
**Future:** S3 backend + DynamoDB lock table.

**Do not commit secrets.** Treat state as sensitive (may contain IPs, IDs).

---

## Providers

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}
```

Default tags: `ManagedBy=Terraform`, `Project`, `Environment`, `Owner`.

---

## Variables

Critical knobs (see `variables.tf` + `terraform.tfvars`):

| Variable | Live value | Why |
|----------|------------|-----|
| `use_custom_vpc` | `true` | Frozen architecture |
| `vpc_cidr` | `10.20.0.0/16` | Address plan |
| `enable_nat_gateway` | `true` | Private outbound |
| `enable_ssm` | `true` | No bastion |
| `enable_ssm_vpc_endpoints` | `true` | Private SSM APIs |
| `enable_ebs_csi` | `true` | PVC → gp3 IAM |
| `instances` | 7 keys | Explicit node inventory |
| `security_groups` | 5 keys | Per-role firewall |

---

## Outputs

Notable outputs: `nginx_eip`, `nat_eip`, `vpc_id`, subnet IDs, `ssm_connect_hint`, `instance_private_ips`, `cluster_summary`.

TODO: Paste sanitized `terraform output` after next apply.

[ Screenshot Required ]

**Description:** Terminal `terraform output` (redact if needed)  
**TODO:** Waiting for screenshot

---

## Modules

| Module | Responsibility |
|--------|----------------|
| `vpc` | VPC, subnets, IGW, NAT, route tables |
| `vpc-endpoints` | Gateway + interface endpoints |
| `iam-ssm` | Instance role/profile + optional EBS CSI policy |
| `security-group` | One SG per map entry |
| `ec2` | Instance + root volume encryption path |

---

## Resources

Created indirectly via modules + root `aws_eip.nginx` / `aws_eip_association.nginx`.

Full resource inventory: regenerate with `terraform state list`.

TODO: Waiting for `terraform state list` paste.

---

## Dependency Graph

Intended create order (`DEPENDENCY_FLOW.md`):

```
VPC → IGW/subnets → public routes → NAT → private routes
  → SGs ∥ IAM SSM ∥ VPC endpoints
  → EC2 nodes (depends_on network+IAM+SG+endpoints)
  → Nginx EIP association
```

**Why explicit `depends_on` on nodes:** Subnet ID references alone do not wait for NAT routes; early boots broke SSM/snap installs.

---

## Provisioning Order (human)

1. Configure `terraform.tfvars` / credentials  
2. `terraform init`  
3. `terraform plan`  
4. `terraform apply`  
5. Confirm SSM Online before Ansible  

[ Screenshot Required ]

**Description:** `terraform plan` summary  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** `terraform apply` completed  
**TODO:** Waiting for screenshot

---

## Resource Lifecycle

| Action | Notes |
|--------|-------|
| Scale workers | Add `worker-N` to `instances` map → apply → Ansible join |
| Change instance type | Expect replace depending on force-new attrs |
| Toggle `use_custom_vpc` | Destructive migration — destroy/rebuild window |
| EIP | Association follows nginx instance replace |

---

## Destroy Process

```bash
# Drain workloads / destroy PVCs first if you need to avoid orphan EBS surprises
cd "Scopify Server/terraform"
terraform destroy
```

**Caveats:**

- EBS volumes from CSI may remain depending on PV reclaim policy (`Delete` on gp3 SC — volumes deleted with PVC).
- Cloudflare DNS will point at freed EIP — remove/update records.
- GHCR images and Git history remain.

**Alternatives to full destroy:** Stop EC2 instances for cost save (NAT still bills if left).

---

## Best Practices (observed + recommended)

**Observed in code:**

- Module boundaries by concern  
- Tagging strategy  
- Encryption on root volumes (module) + gp3 SC `encrypted=true`  
- Dependency hardening for NAT/SSM  

**Recommended next:**

- Remote state  
- `terraform fmt` / `validate` in CI  
- Separate tfvars per env  
- Deny public SG on SSH via policy guardrails  

---

## Terraform Graph

[ Screenshot Required ]

**Description:** `terraform graph | dot -Tpng > graph.png`  
**Purpose:** Visual dependency evidence  
**TODO:** Waiting for screenshot

---

## Related ADRs

- [ADR-008 Terraform](../decisions/ADR-008-terraform.md)  
- [ADR-002 SSM](../decisions/ADR-002-ssm-vs-bastion.md)  
- [ADR-003 VPC Endpoints](../decisions/ADR-003-vpc-endpoints.md)
