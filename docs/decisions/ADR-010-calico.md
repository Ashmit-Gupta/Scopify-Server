# ADR-010: Calico as cluster CNI

- **Status:** Accepted  
- **Evidence:** `calico_version: v3.29.4` in `group_vars/all.yml`; cluster SG Calico rules

## Context

kubeadm requires a CNI for pod networking across nodes.

## Decision

Install **Project Calico** from the official manifest URL, pinned to **v3.29.4** (not newest v3.32.x) to avoid ClusterNetworkPolicy CEL `isCIDR` apply failures on API servers missing required libraries.

## Alternatives

| Option | Notes |
|--------|-------|
| flannel | Simpler; fewer NetworkPolicy features |
| Amazon VPC CNI | EKS-oriented; not natural on kubeadm EC2 without AWS plumbing |
| Cilium | Powerful eBPF; heavier learning/ops for this lab size |

## Tradeoffs

- **+** NetworkPolicy path later; production-common  
- **−** SG must allow BGP + IPIP (and optionally VXLAN)  
- **−** Version pin required for CRD compatibility  

## Consequences

Security group documentation must mention protocol 4. Upgrades of Calico are intentional events, not drive-by.
