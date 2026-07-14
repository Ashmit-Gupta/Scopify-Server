# AWS access model — Custom VPC + SSM (no bastion)

> How you connect to private EC2s without SSH bastion or (optionally) without VPC endpoints.

---

## Short answer

| Question | Answer |
|----------|--------|
| Were SSM endpoints (`ssm`, `ssmmessages`, `ec2messages`) added before? | **Module existed, but they were OFF** (`enable_vpc_endpoints = false`). |
| Are they wired now? | **Yes** — set `enable_ssm_vpc_endpoints = true` (with `use_custom_vpc = true`) to create exactly those three Interface endpoints. |
| Is NAT still required when using SSM? | **For SSM alone: no**, if those three endpoints exist. **For this Scopify lab: yes, you still want NAT** (Docker Hub, GHCR, apt, Helm, Let’s Encrypt, etc.). |

### Two valid SSM designs

**Design A — NAT only (what we recommended earlier)**  
`enable_nat_gateway = true`, `enable_ssm_vpc_endpoints = false`  
Agent reaches public SSM APIs via NAT. No Interface endpoint hourly cost.

**Design B — SSM endpoints (no dependency on NAT for SSM)**  
`enable_ssm_vpc_endpoints = true` → creates:
- `com.amazonaws.<region>.ssm`
- `com.amazonaws.<region>.ssmmessages`
- `com.amazonaws.<region>.ec2messages`

SSM works even with `enable_nat_gateway = false`.  
But without NAT, private nodes **cannot** pull from Docker Hub/GHCR or run `apt update` unless you add more endpoints (ECR, S3) and stay on AWS-only registries.

**Design C — both (common in real labs)**  
NAT **and** SSM endpoints: SSM stays private to AWS network; NAT still covers general internet. Costs more (NAT + 3 interface endpoints).

```
Recommended for Scopify learning rebuild:
  use_custom_vpc           = true
  enable_nat_gateway       = true          # internet for images/apt
  enable_ssm               = true          # IAM + agent
  enable_ssm_vpc_endpoints = true          # optional but explicit SSM path
  enable_vpc_endpoints     = false         # leave general ECR/etc off unless needed
```

```
You (laptop)
   │  AWS CLI / Console Session Manager
   ▼
AWS Systems Manager service (public AWS API)
   │  (agent phones home outbound)
   ▼
NAT Gateway (public subnet)
   │
   ▼
Private EC2 (SSM agent + IAM instance profile)
```

Classic SSH:

```
You → port 22 → instance
```

Only works if the instance has a route from the internet (public IP) or you jump through a bastion. **Private-only nodes: use SSM instead of SSH.**

---

## What Terraform now provides

| Piece | Module / flag |
|-------|----------------|
| Custom VPC, subnets, IGW, NAT, route tables | `modules/vpc` + `use_custom_vpc = true` |
| IAM role + instance profile (`AmazonSSMManagedInstanceCore`) | `modules/iam-ssm` + `enable_ssm = true` |
| Ubuntu user_data to install `amazon-ssm-agent` | `install_ssm_agent = true` |
| Optional VPC endpoints | `enable_vpc_endpoints` (not required with NAT) |
| Nginx EIP when instance key `nginx` exists | root `main.tf` |

Connect example (after instance shows **Online** in SSM Fleet Manager):

```bash
aws ssm start-session --target i-0123456789abcdef0 --region ap-south-1
```

Optional SSH-over-SSM (keeps `ssh` UX, still no open port 22):

```bash
aws ssm start-session --target i-... \
  --document-name AWS-StartSSHSession \
  --parameters portNumber=22
```

---

## Custom VPC settings you want

```hcl
use_custom_vpc       = true
enable_nat_gateway   = true   # required for SSM without VPC endpoints
enable_ssm           = true
install_ssm_agent    = true
enable_vpc_endpoints = false  # keep off while NAT is on (saves money)

# Later optional:
# enable_vpc_endpoints = true
# vpc_endpoint_interface_enabled = true
# vpc_endpoint_interface_services = ["ssm", "ssmmessages", "ec2messages"]
```

Instance placement:

```hcl
nginx   → subnet_tier = "public"   # + EIP
jenkins → subnet_tier = "private"  # SSM only
master / workers → subnet_tier = "private"
```

Security groups for private nodes: **no inbound 22 from 0.0.0.0/0**. SSM does not need inbound SSH. Egress HTTPS (443) must be allowed (default “allow all egress” is fine).

---

## Ansible note

Today `ansible/inventories/aws_ec2.yml` uses `public_ip_address`. On a private-only fleet that breaks.

Options later:

1. `ansible_host: private_ip_address` + run Ansible from a host inside the VPC, or  
2. Ansible connection plugin `aws_ssm` (Session Manager), or  
3. `aws ssm start-session` port forwarding for one-off access  

Track this as a follow-up when you flip `use_custom_vpc = true`.

---

## Warning: migrating the current lab

Your **running** 6 EC2s are on the **default VPC**. Setting `use_custom_vpc = true` and applying will **not** gently move them — expect replace/recreate. Prefer:

1. Snapshot / note configs  
2. `terraform destroy` (or remove old instances from state deliberately)  
3. Apply fresh with custom VPC + SSM  
4. Re-run Ansible  
**Or** keep default VPC until a planned rebuild weekend.
