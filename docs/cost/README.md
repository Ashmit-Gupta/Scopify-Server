# Cost

Cost posture for the Scopify lab/platform. Figures are **order-of-magnitude engineering guidance**, not invoices.

TODO: Waiting for AWS Cost Explorer screenshot / actual monthly bill.

---

## Cost Philosophy

1. Prefer **one public entry** over many EIPs/LBs.  
2. Pay for **NAT + small always-on footprint** to learn real private networking.  
3. Defer expensive add-ons (full VPC endpoint sets, ALB, EKS, large Prometheus retention) until needed.  
4. Destroy or stop when idle.

---

## Major Cost Drivers (expected)

| Item | Why it costs | Control lever |
|------|--------------|---------------|
| NAT Gateway | Hourly + data | Single NAT (AZ SPOF accepted); stop lab / destroy |
| EC2 ×7 | Compute hours | Right-size (`t3.small` nginx); stop instances |
| EBS volumes | gp3 GB-month | 20–40 GB roots; PVC sizes 2–10 Gi |
| Elastic IPs | Usually free while associated | Avoid unattached EIPs |
| SSM Interface endpoints | Hourly per AZ/ENI | Only SSM trio enabled |
| Data transfer | NAT egress (GHCR pulls, apt) | Cache; fewer rebuilds |
| Cloudflare | DNS free tier typical | TODO confirm plan |

**Not deployed (avoids cost today):** ALB, EKS control plane, multi-NAT, full ECR interface endpoints, always-on large Prometheus PVCs (commented).

---

## Decisions That Explicitly Save Money

| Decision | Alternative rejected | Savings intent |
|----------|----------------------|----------------|
| Nginx edge vs ALB | ALB LCU + complexity | Lower $; more learning |
| kubeadm vs EKS | EKS ~$0.10/hr control plane | Avoid fixed EKS fee |
| GHCR vs ECR | ECR storage/API | Use GitHub package quota |
| SSM vs bastion | Extra `t3` bastion | One fewer instance |
| Disable extra interface endpoints | ECR/logs PrivateLink | Cut hourly endpoints |
| Monitoring Application commented | Full kube-prometheus-stack | Defer PVC/CPU |

---

## Decisions That Intentionally Spend Money

| Spend | Why accepted |
|-------|----------------|
| NAT Gateway | Real private subnets |
| SSM endpoints | Reliable admin without fighting NAT-only edge cases |
| Second worker | Capacity + multi-AZ practice |
| Sonar + Nexus EC2s | Temporary convenience (target: retire into K8s) |

---

## Optimization Backlog

1. Move Sonar/Nexus into cluster → delete 2× `c7i-flex.large`  
2. Schedule EC2 stop/start for non-demo hours  
3. Remote state is free-ish on S3 but prevents costly rebuild mistakes  
4. Image GC on GHCR  
5. Revisit NAT Instance if lab resumes long-term cheap mode  
6. Budgets + billing alarm (account-level; noted missing in `AWS_GAPS.md`)

---

## Scalability vs Cost

| Scale action | Cost impact |
|--------------|-------------|
| +1 worker | +EC2 +EBS +NAT data |
| API HPA | More pod density before new node |
| Multi-NAT | ≈×AZ NAT hourly |
| EKS migration | +control plane fee; possibly fewer master EC2s |
| RDS instead of in-cluster Postgres | +RDS hours; better isolation |

---

## Evidence Placeholders

[ Screenshot Required ]

**Description:** AWS Billing → Cost Explorer by service (EC2, EC2-Other/NAT, VPC endpoints)  
**Purpose:** Validate assumptions  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** Budgets alarm (if created)  
**TODO:** Waiting for screenshot
