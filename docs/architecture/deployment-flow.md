# Deployment Flow

## Purpose

Define the approved path from code change to running pods, and what must never be done in the happy path (manual `kubectl set image` without Git).

## Architecture

Split ownership:

- **scopify-backend** Git repo — application source + Jenkinsfile  
- **Scopify-Server** Git repo — desired Kubernetes state under `k8s/scopify-backend/{dev,prod}`  
- **GHCR** — immutable-ish image tags (`git rev-parse --short=7 HEAD`)  
- **Argo CD** — reconciler  

## Flow

```
1. Developer pushes to GitHub (branch main or dev)
2. Jenkins job (Pipeline from SCM) checks out backend
3. Jenkins clones Scopify-Server (main)
4. Maps branch → env:
     main → K8S_ENV=prod, NS=scopify-prod
     dev  → K8S_ENV=dev,  NS=scopify-dev
5. docker build → tag ghcr.io/ashmit-gupta/scopify-backend:<sha>
6. Trivy FS + image (exit-code 0 — report only)
7. docker push (sha + latest)
8. sed image lines in api-deployment.yml + migrate-job.yml
9. git commit/push to Scopify-Server
10. Argo CD detects drift / auto-sync (per Application settings)
11. PreSync Job: prisma migrate deploy
12. Deployment rolls out new image
13. Readiness /health → traffic
```

## Components

Jenkins credentials `github-token`, Docker socket on Jenkins agent, GHCR, Kustomize trees, Argo PreSync annotations, `/health` probes.

## Tradeoffs

- **Git as deploy API** — auditable, recoverable; slower than direct kubectl; requires write access to Server repo.
- **`latest` also pushed** — convenience; prod manifests use SHA tags (preferred).
- **Sonar stages disabled** — faster green builds; quality gate not enforced until re-enabled.
- **Secrets not in Argo sync** — safer Git hygiene; bootstrap requires manual secret apply.

## Future Improvements

- Re-enable Sonar + Quality Gate with private webhook URL (Cloudflare blocks public webhook path — noted in Jenkinsfile)
- Image digest pinning (`@sha256:`) instead of mutable tag alone
- Separate deploy repo or protected `main` rules for Server

## Diagram

[ Screenshot Required ]

**Description:** Jenkins full pipeline success + Argo sync Healthy  
**Purpose:** Prove CD path end-to-end  
**Evidence:** Jenkinsfile + migrate Job annotations  
**TODO:** Waiting for screenshot
