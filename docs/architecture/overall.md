# Overall Architecture

## Purpose

Describe the end-to-end Scopify platform as an engineer would brief a new hire: what runs where, which control planes own which lifecycle, and which boundaries are intentional.

## Architecture

The platform has four control planes:

| Control plane | Tool | Owns |
|---------------|------|------|
| Cloud resources | Terraform | VPC, subnets, routes, NAT, EIPs, EC2, SGs, IAM, VPC endpoints |
| Node software | Ansible | containerd, kubeadm, Calico, Ingress-Nginx, Jenkins/Sonar/Nexus Docker, Nginx edge |
| Desired cluster state | Git + Argo CD | Deployments, Services, Ingress, Jobs, StorageClass references |
| Application CI | Jenkins | Image build, scan, push, manifest tag bump |

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cloudflare DNS                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                      Nginx EIP (public)
                             │
┌────────────────────────────▼────────────────────────────────────┐
│ Public subnet                                                   │
│  Nginx EC2 (TLS, Host routing)     NAT Gateway                  │
└──────────────┬─────────────────────────────┬────────────────────┘
               │ proxy                       │ outbound
┌──────────────▼─────────────────────────────▼────────────────────┐
│ Private subnets                                                 │
│  Jenkins │ Sonar │ Nexus │ Master │ Worker-1 │ Worker-2         │
│                              │                                  │
│                    Kubernetes (kubeadm)                         │
│           scopify-dev / scopify-prod / argocd / ingress-nginx   │
└─────────────────────────────────────────────────────────────────┘
```

## Flow

1. Humans resolve `*.ashmit.xyz` → Cloudflare → Nginx EIP.
2. Nginx terminates TLS (wildcard Let’s Encrypt) and routes by `Host`.
3. Tool hosts (`jenkins` / `sonar` / `nexus`) proxy to private EC2 ports.
4. App / Argo hosts proxy to Ingress-Nginx **NodePort** on worker IPs.
5. Ingress routes to Services → Pods.
6. Admins reach private EC2 via **SSM** (or SSH ProxyJump via Nginx).

## Components

| Component | Location | Notes |
|-----------|----------|-------|
| Nginx edge | Public EC2 | Sole intentional public compute |
| Jenkins | Private EC2 | CI; holds kubeconfig for optional kubectl |
| Sonar / Nexus | Private EC2 | Temporary; target = in-cluster |
| Control plane | Master EC2 | Single master (lab SPOF) |
| Data plane | worker-1, worker-2 | Across 2 AZ private subnets |
| Scopify API | K8s Deployment | GHCR image |
| Postgres / Redis | K8s + gp3 PVC | In-namespace data |
| Argo CD | K8s | GitOps reconciler |

## Tradeoffs

| Decision | Benefit | Cost / risk |
|----------|---------|-------------|
| kubeadm on EC2 | Deep learning; full control | No EKS control-plane SLA; upgrade burden |
| Single Nginx | Cheap, simple DNS | SPOF for all HTTPS |
| Single NAT | Lower cost | AZ failure kills private outbound |
| Jenkins outside cluster | Isolates CI resource spikes | Extra EC2 always-on cost |
| Local Terraform state | Simple solo lab | Team/prod anti-pattern; loss risk |

## Future Improvements

- HA control plane / managed EKS if product leaves lab status
- ALB path (ARCHITECTURE Phase 3)
- Retire Sonar/Nexus EC2s
- Remote state + CI for Terraform

## Diagram

[ Screenshot Required ]

**Description:** Overall architecture (prefer `Scopify Server/docs/Scopify-Server-Architecture.drawio`)  
**Purpose:** Visual system context  
**Evidence:** Matches Terraform instance map + Ansible edge  
**TODO:** Waiting for screenshot / exported PNG
