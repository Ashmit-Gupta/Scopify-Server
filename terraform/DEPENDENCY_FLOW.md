# Terraform create order (dependency flow)

Terraform builds a graph from references + `depends_on`. This is the intended order for **custom VPC** mode.

```
1. VPC
2. IGW + public/private subnets
3. Public route table + 0.0.0.0/0 → IGW + public associations
4. NAT EIP → NAT Gateway (waits for IGW + public subnet association)
5. Private route 0.0.0.0/0 → NAT + private associations
6. Security groups (need vpc_id)
7. IAM SSM role + instance profile          ⎤ can run parallel with 6
8. VPC endpoints (SSM interface / optional) ⎥ need VPC + private subnets + RTs
9. EC2 instances  ← depends_on VPC module, endpoints, IAM, SGs
10. Nginx EIP → associate to nginx instance
```

## What was wrong before

`module.nodes` only referenced **subnet IDs**. That does **not** wait for NAT or private routes.

So private EC2 could boot before outbound (NAT) / SSM endpoints were ready → snap/SSM agent failures.

## What we fixed

| Place | Fix |
|-------|-----|
| `modules/vpc` | NAT waits for IGW + public RT association; private RT association waits for NAT route |
| `modules/vpc` output `network_ready` | Ties associations + NAT into one readiness token |
| `module.nodes` | Explicit `depends_on` → `module.vpc`, `module.vpc_endpoints`, `module.iam_ssm`, `module.security_groups` |
| `aws_eip.nginx` | `depends_on = [module.vpc]` (IGW must exist for VPC EIP) |
| `aws_eip_association.nginx` | Implicit wait on nginx instance + EIP |
| VPC interface endpoints | `depends_on` endpoint SG |

## Parallelism (safe)

These can create at the same time after VPC exists:

- Security groups  
- IAM SSM profile  
- VPC endpoints (after subnets/RTs from VPC module outputs)

EC2 starts only after the `depends_on` list is complete.

## Not handled by Terraform (runtime)

- SSM agent showing **Online** can still take 1–2 minutes after boot (IAM propagation + agent register).  
- Wait with: `aws ssm describe-instance-information` before `start-session`.
