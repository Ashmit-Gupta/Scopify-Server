# CI/CD Flow

## Purpose

Detail continuous integration and the handoff to continuous delivery (GitOps), including intentionally disabled stages.

## Architecture

```
GitHub scopify-backend
        │
        ▼
Jenkins (private EC2, Docker agent)
        │
        ├── SonarQube Analysis     [DISABLED when { false }]
        ├── Quality Gate           [DISABLED when { false }]
        ├── docker build
        ├── trivy fs + image       [non-blocking exit-code 0]
        ├── push GHCR
        └── commit Scopify-Server manifests
                │
                ▼
         Argo CD (CD)
```

GitHub Actions workflow `docker-build.yml` exists but is **hard-disabled** (`if: false`) — Jenkins is the canonical builder.

## Flow

See Jenkinsfile stages in [jenkins/](../jenkins/README.md). Branch policy: only `dev` and `main` deploy; others fail Checkout.

## Components

| Component | Role |
|-----------|------|
| `github-token` credential | GHCR + clone/push Server |
| `SONAR_SERVER = SonarQube` | When stages re-enabled |
| Trivy on host + bind into Jenkins container | Ansible `roles/trivy` |
| Image repo | `ghcr.io/ashmit-gupta/scopify-backend` |

## Tradeoffs

- **Jenkins on EC2** vs GitHub Actions: keeps builds inside VPC near Sonar/Nexus/cluster; more ops ownership.
- **Report-only Trivy**: visibility without blocking learning velocity; unsafe for strict prod gates.
- **Webhook to public Jenkins hostname**: Cloudflare interference documented — prefer private IP webhook.

## Future Improvements

- Enforce HIGH/CRITICAL Trivy failures on `main`
- Re-enable Sonar with private webhook
- Build provenance / SBOM attach
- Separate CD bot identity from personal GitHub PAT

## Diagram

[ Screenshot Required ]

**Description:** Jenkins Blue Ocean / classic stage view of a green `main` build  
**Purpose:** CI evidence for portfolio / incident forensics  
**TODO:** Waiting for screenshot
