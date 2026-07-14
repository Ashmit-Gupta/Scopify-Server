# Terraform modules — Scopify Server

```
terraform/
├── main.tf                 # wires modules + optional nginx EIP
├── locals.tf
├── variables.tf
├── outputs.tf
├── modules/
│   ├── vpc/                # VPC, subnets, IGW, NAT, route tables
│   ├── vpc-endpoints/      # optional Gateway + Interface endpoints
│   ├── security-group/     # one SG per map key (CIDR or SG sources)
│   └── ec2/                # one EC2 per map key
└── terraform.tfvars.example
```

## Module roles

| Module | Creates | Required for frozen arch? |
|--------|---------|---------------------------|
| `vpc` | VPC, public/private subnets, IGW, route tables, optional NAT+EIP | **Yes** (when leaving default VPC) |
| `security-group` | Security groups + rules | **Yes** |
| `ec2` | EC2 instances (+ optional IAM profile / user_data) | **Yes** |
| `iam-ssm` | Instance profile for Session Manager | **Yes** if private + no bastion |
| `vpc-endpoints` | S3 gateway (+ optional Interface SSM/ECR/…) | **No** if NAT is on; **Yes** for SSM if NAT is off |

## Access without bastion

See **[`AWS_ACCESS.md`](./AWS_ACCESS.md)** and **[`AWS_GAPS.md`](./AWS_GAPS.md)**.

Summary: private EC2s + **NAT** + **SSM IAM** + **SSM agent** = connect with Session Manager; VPC endpoints optional.

## VPC endpoints — required or not?

**Not required** for this project if:

- Private instances use a **NAT Gateway** for outbound (Docker Hub, GHCR, apt, Helm), or  
- You stay on Track A (default VPC / hybrid) for now.

**Useful later** when you want:

| Endpoint type | Examples | Cost | Why |
|---------------|----------|------|-----|
| Gateway | `s3` | No hourly fee | Pulls from S3 without NAT data charges |
| Interface | `ecr.api`, `ecr.dkr`, `ssm`, `ec2`, `logs` | Hourly + data | Private AWS API access; SSM without bastion |

Docker Hub / GHCR / Squarespace / Let's Encrypt **do not** go through VPC endpoints — NAT (or public IP) is still needed for those.

Defaults in root variables:

- `enable_vpc_endpoints = false`
- Gateway S3 ready when you turn endpoints on
- Interface endpoints off until you explicitly need them

## Feature flags

```hcl
use_custom_vpc       = false  # keep current lab on default VPC
enable_nat_gateway   = true   # only applies when use_custom_vpc = true
enable_vpc_endpoints = false  # only applies when use_custom_vpc = true
```

When `use_custom_vpc = true`, set per-instance:

```hcl
subnet_tier = "public"   # Nginx
subnet_tier = "private"  # Jenkins, K8s nodes (default if omitted)
```

If an instance key `nginx` exists, root `main.tf` allocates and associates an **Elastic IP** automatically.

## Safe migration note

Flipping `use_custom_vpc` from `false` → `true` with existing instances in state will try to **move/replace** networking and likely recreate EC2s. Treat custom VPC as a planned migration (or destroy lab first), not a silent toggle on production-like state.
