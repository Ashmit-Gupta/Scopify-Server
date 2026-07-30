# ADR-002: AWS SSM Session Manager instead of a bastion host

- **Status:** Accepted  
- **Evidence:** `modules/iam-ssm`, `enable_ssm`, `AWS_GAPS.md` (“Bastion not planned”)

## Context

Private subnet instances need an admin shell without placing SSH on `0.0.0.0/0` for every node.

## Decision

Attach an IAM instance profile with `AmazonSSMManagedInstanceCore`, install SSM Agent via cloud-init, and use **Session Manager** as the primary access path. No bastion EC2.

## Alternatives

| Option | Notes |
|--------|-------|
| Bastion / jump host | Extra public SSH surface + patching |
| VPN (Client VPN / Tailscale) | Strong; more moving parts for lab |
| Public SSH on all nodes | Rejected for frozen architecture |

## Tradeoffs

- **+** IAM-auditable sessions; no inbound 22 required on private SGs (still allowed from VPC for Ansible flexibility)  
- **+** Works with private IPs  
- **−** Depends on agent health + IAM + network path to SSM APIs  
- **−** Learning curve vs muscle-memory SSH  

## Consequences

VPC endpoints for SSM and/or NAT are mandatory. Ansible may still ProxyJump via Nginx for SSH-based plays.
