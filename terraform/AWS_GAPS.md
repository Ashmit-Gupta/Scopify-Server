# AWS gap checklist — Scopify Server (now)

What you need on AWS for the frozen architecture, vs what Terraform covers today.

## Access model (your choice)

| Approach | Status in repo |
|----------|----------------|
| Custom VPC + private subnets | Module ready (`use_custom_vpc`) |
| NAT for private outbound | Module ready (`enable_nat_gateway`) |
| SSM Session Manager (no bastion) | **IAM module + user_data ready** (`enable_ssm`) |
| VPC endpoints for SSM | Optional module — **not needed if NAT is on** |
| Bastion host | **Not planned** (SSM replaces it) |

## Already in Terraform (modules / wiring)

- [x] EC2 module  
- [x] Security group module (CIDR + SG sources supported)  
- [x] Custom VPC + route tables + IGW + NAT  
- [x] VPC endpoints module (optional)  
- [x] IAM instance profile for SSM  
- [x] Ubuntu SSM agent cloud-init  
- [x] Nginx EIP when `nginx` instance exists  
- [x] Default-VPC mode still available (`use_custom_vpc = false`)

## Still missing / not turned on yet (AWS side)

### Must have for frozen target

| Gap | Notes |
|-----|--------|
| Flip to custom VPC in **live** tfvars + rebuild | Still `use_custom_vpc = false` to protect current lab |
| Nginx EC2 + nginx SG in tfvars | Edge not defined in active config yet |
| SG lockdown (tools only from Nginx SG; no world :8080/:9000/:8081) | Rules still `0.0.0.0/0` in tfvars |
| Admin IP restriction on SSH (or remove SSH entirely once SSM works) | Still open in lab SGs |
| Squarespace DNS → Nginx EIP | Outside Terraform |
| Ansible inventory for **private** IPs / ProxyJump / SSM | **Updated** — see `ansible/inventories/aws_ec2.yml`, `site-nginx.yml`, `cmds.md` |

### Should have soon

| Gap | Notes |
|-----|--------|
| EBS encryption defaults / KMS CMK (optional hardening) | Root volumes already `encrypted = true` with AWS managed key |
| CloudWatch agent / log groups | Not in Terraform |
| AWS Backup or snapshot schedule | Not in Terraform |
| Budgets / billing alarm | Account-level, not in this repo |
| S3 backend for Terraform state | Local state today (risky for team/prod) |

### Later (architecture phases)

| Gap | Notes |
|-----|--------|
| In-cluster Sonar/Nexus/Scopify (not EC2) | K8s/Helm, not more EC2 modules |
| ACM or Certbot TLS | Edge Nginx / later ALB |
| Route 53 hosted zone | Optional vs Squarespace |
| ALB + AWS LB Controller | Phase 3 only |
| WAF, Shield, GuardDuty | Production hardening |

### Not missing for SSM-without-endpoints

- Bastion  
- Interface VPC endpoints **if NAT is enabled**

---

## Recommended next AWS actions

1. Read [`AWS_ACCESS.md`](./AWS_ACCESS.md).  
2. Plan a **rebuild window** (custom VPC + SSM will replace current default-VPC nodes).  
3. Set in tfvars for the new stack:  
   `use_custom_vpc = true`, `enable_nat_gateway = true`, `enable_ssm = true`, `enable_vpc_endpoints = false`.  
4. Add `nginx` (public) + keep jenkins/k8s private.  
5. After apply: confirm instances **Online** in SSM → `aws ssm start-session`.  
6. Tighten SGs; drop public SSH.
