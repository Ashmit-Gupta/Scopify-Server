# ADR-001: kubeadm on EC2 instead of Amazon EKS

- **Status:** Accepted  
- **Date:** 2026-07 (frozen architecture era)  
- **Evidence:** Ansible `site.yml` / `group_vars/all.yml`; ARCHITECTURE.md

## Context

Scopify needs a Kubernetes runtime for the API and future platform add-ons. Options range from fully managed EKS to self-managed kubeadm on EC2.

## Decision

Run a **kubeadm** cluster on private EC2 (`master` + `worker-1` + `worker-2`), bootstrapped by Ansible, with pinned versions (Kubernetes 1.35.6).

## Alternatives

| Option | Why not (now) |
|--------|----------------|
| Amazon EKS | Higher cost; hides control-plane learning; less portable “bare” skills |
| k3s / k0s | Excellent for labs but less representative of classic kubeadm ops |
| ECS/Fargate only | Diverges from K8s/GitOps learning goals |

## Tradeoffs

- **+** Full control of etcd, CNI, Ingress, CSI wiring  
- **+** Lower fixed control-plane cost than EKS for intermittent lab  
- **−** No AWS-managed control-plane SLA; single master SPOF  
- **−** Upgrade/security patching owned by operator  
- **−** No built-in AWS LB Controller without extra install  

## Consequences

Documentation, troubleshooting, and ADRs must cover kubeadm-specific failure modes. Future “production product” hosting may revisit EKS (ARCHITECTURE Phase 3 adjacent).
