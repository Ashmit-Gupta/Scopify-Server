# ADR-006: GHCR as the container registry

- **Status:** Accepted  
- **Evidence:** Jenkinsfile `IMAGE_REPO = ghcr.io/ashmit-gupta/scopify-backend`; Actions workflow (disabled)

## Context

Images must be stored somewhere pullable by private nodes (via NAT). Nexus exists on EC2 for lab artifact learning; GHCR integrates with GitHub auth.

## Decision

Publish Scopify API images to **GitHub Container Registry**. Tag with short git SHA; also push `latest` for convenience.

## Alternatives

| Option | Notes |
|--------|-------|
| ECR | Native IAM pull; extra AWS cost/auth wiring |
| Nexus Docker hosted | Aligns with lab Nexus; more ops; target may move in-cluster |
| Docker Hub | Rate limits; less GitHub-native |

## Tradeoffs

- **+** Simple PAT auth shared with Git operations  
- **−** Cluster needs imagePullSecret for private packages  
- **−** Less “all AWS” narrative  

## Consequences

Document GHCR permissions for CI token. Future: dual-publish to in-cluster Nexus/ECR if desired.
