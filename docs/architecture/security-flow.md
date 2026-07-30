# Security Flow

## Purpose

Describe how trust boundaries are enforced from Internet → edge → VPC → node → pod, and where the lab intentionally accepts residual risk.

## Architecture

```
Internet
  │  SG nginx: 22/80/443 from 0.0.0.0/0   ← lab risk
  ▼
Nginx (TLS 1.2/1.3)
  │  proxy only to VPC private IPs
  ▼
Private EC2 / NodePorts
  │  SG rules from 10.20.0.0/16
  ▼
Pods (no public IPs)
  │  Secrets via K8s Secret objects (manual)
  ▼
Data (encrypted gp3 EBS: StorageClass encrypted=true)
```

Admin path bypasses SSH-from-Internet on private nodes via **SSM**.

## Flow

1. External request must hit Nginx EIP (or be dropped by lack of public IP).
2. Host header must match a configured server block.
3. Upstream is private; tool SGs do not list `0.0.0.0/0` for app ports.
4. Cluster SG exposes API `6443` and NodePorts only within VPC CIDR.
5. Container images pulled from GHCR using `ghcr-secret` imagePullSecret where configured.
6. Trivy reports CVEs during CI (non-gating).

## Components

IAM SSM profile, EBS CSI policy attachment, VPC endpoints for SSM, Calico (network fabric; NetworkPolicies not yet documented as applied), gitignored secrets, Cloudflare API token for DNS-01.

## Tradeoffs

- Lab SSH on Nginx open to world — convenient Ansible/ProxyJump; **high priority to lock down**.
- VPC-CIDR-wide cluster rules — simpler than per-SG references; broader lateral movement surface inside VPC.
- In-cluster Postgres — blast radius if cluster compromised; RDS would isolate DB IAM/network further.

## Future Improvements

See [security/](../security/README.md) hardening list.

## Diagram

[ Screenshot Required ]

**Description:** AWS Console → Security Groups summary  
**Purpose:** Evidence of private vs public exposure  
**TODO:** Waiting for screenshot
