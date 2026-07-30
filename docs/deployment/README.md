# Deployment

End-to-end deployment process for Scopify API onto Kubernetes.

---

## Pipeline at a Glance

```
Developer
   ↓
GitHub (scopify-backend branch main|dev)
   ↓
Jenkins (Pipeline from SCM)
   ↓
Docker build (backend/Dockerfile)
   ↓
GHCR (ghcr.io/ashmit-gupta/scopify-backend:<sha7>)
   ↓
Git commit (Scopify-Server k8s manifests image:)
   ↓
Argo CD reconcile
   ↓
Kubernetes (PreSync migrate → Deployment)
   ↓
Running Pods (Service + Ingress + edge Nginx)
```

---

## Stage Detail

### 1. Developer

Implements NestJS changes; runs local compose/tests as needed; pushes to `dev` or `main`.

### 2. GitHub

Source of truth for application code. Webhook/poll triggers Jenkins (**TODO:** confirm trigger mode screenshot).

### 3. Jenkins

Checks out backend; clones Server; validates Dockerfile + k8s paths exist; refuses other branches.

### 4. Docker

Builds image tagged with short git SHA and `latest`.

### 5. GHCR

Authenticated push using `github-token`. Cluster pulls via `ghcr-secret` when private.

### 6. Git Commit

Updates:

- `k8s/scopify-backend/<env>/api/api-deployment.yml`
- `k8s/scopify-backend/<env>/migrate/migrate-job.yml`

Commit message: `ci(<env>): deploy <tag>`.

### 7. Argo CD

Detects Git change; starts sync.

### 8. Kubernetes

1. PreSync Job runs `npx prisma migrate deploy --config prisma.config.ts`  
2. API Deployment rolls to new image  
3. Probes `/health`  

### 9. Running Pods

Traffic:

`Client → Cloudflare → Nginx → NodePort → Ingress → Service → Pod`

Hostnames:

- Prod: `https://aws-api.ashmit.xyz`  
- Dev: `https://dev-aws-api.ashmit.xyz`  

---

## Bootstrap (first deploy)

1. Apply namespace  
2. Apply secrets from examples (never commit real files)  
3. Ensure `ghcr-secret` if package private  
4. Ensure Argo Application exists and syncs Kustomize root  
5. Ensure edge Nginx + DNS for API host  
6. Run pipeline or seed manifests manually  

Evidence: `k8s/README.md`.

---

## Platform Bootstrap (cluster from zero)

See networking/terraform docs + `SERVER_STRUCTURE.md` lifecycle:

`terraform apply` → SSM Online → `site.yml` → `site-tools.yml` → DNS → `site-nginx.yml` → Argo/apps.

---

## Rollback

See [jenkins/](../jenkins/README.md#rollback) and [argocd/](../argocd/README.md#rollback).

---

## Verification Checklist

- [ ] Jenkins build green  
- [ ] GHCR tag visible  
- [ ] Server repo commit present  
- [ ] Argo Synced/Healthy  
- [ ] `kubectl get pods -n scopify-prod` Running  
- [ ] `curl -fsS https://aws-api.ashmit.xyz/health`  

[ Screenshot Required ]

**Description:** End-to-end proof collage (Jenkins + Argo + curl)  
**TODO:** Waiting for screenshot
