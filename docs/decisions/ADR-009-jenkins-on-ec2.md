# ADR-009: Jenkins on a dedicated private EC2

- **Status:** Accepted  
- **Evidence:** ARCHITECTURE design lock “CI stays on dedicated EC2”; tfvars `jenkins` instance; Ansible jenkins role

## Context

CI needs Docker builds, optional Sonar integration, and Git credentials. Running Jenkins inside the app cluster couples platform failure domains.

## Decision

Keep **Jenkins on its own private EC2**, exposed only via Nginx hostname, with Docker socket + Trivy + kubeconfig available to the container.

## Alternatives

| Option | Notes |
|--------|-------|
| Jenkins in Kubernetes | Possible; noisier multi-tenant scheduling on small workers |
| GitHub Actions only | Simpler; less VPC-local integration; workflow currently disabled |
| Buildkite/other | Out of scope |

## Tradeoffs

- **+** Isolates build CPU/disk from API nodes  
- **+** Familiar classic CI for portfolio storytelling  
- **−** Always-on EC2 cost  
- **−** Patch/backup Jenkins VM separately  

## Consequences

Sonar webhooks should use private IP. Jenkins is not the CD reconciler — Argo is.
