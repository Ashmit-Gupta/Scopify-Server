# Architecture Decision Records

ADRs capture **why** Scopify infrastructure looks the way it does. Each record is durable after AWS resources are deleted.

| ID | Title | Status |
|----|-------|--------|
| [ADR-001](./ADR-001-kubeadm-vs-eks.md) | kubeadm instead of EKS | Accepted |
| [ADR-002](./ADR-002-ssm-vs-bastion.md) | SSM instead of bastion | Accepted |
| [ADR-003](./ADR-003-vpc-endpoints.md) | VPC endpoints for SSM | Accepted |
| [ADR-004](./ADR-004-nginx-edge.md) | Nginx as sole public edge | Accepted |
| [ADR-005](./ADR-005-argocd.md) | Argo CD for CD | Accepted |
| [ADR-006](./ADR-006-ghcr.md) | GHCR as container registry | Accepted |
| [ADR-007](./ADR-007-kustomize.md) | Kustomize over Helm for app | Accepted |
| [ADR-008](./ADR-008-terraform.md) | Terraform for AWS foundation | Accepted |
| [ADR-009](./ADR-009-jenkins-on-ec2.md) | Jenkins on dedicated EC2 | Accepted |
| [ADR-010](./ADR-010-calico.md) | Calico CNI | Accepted |

Template fields used: Context · Decision · Alternatives · Tradeoffs · Consequences.
