# Kubernetes manifests — Scopify Server

Plain YAML (no Kustomize). Two environments as separate folders:

| Folder | Namespace | Ingress host |
|--------|-----------|--------------|
| `scopify-backend/prod/` | `scopify-prod` | `api.ashmit.xyz` |
| `scopify-backend/dev/` | `scopify-dev` | `api-dev.ashmit.xyz` |

## Folder layout (prod and dev mirror each other)

```
scopify-backend/prod/
├── namespace/
│   └── namespace.yml
├── secrets/
│   └── secret.example.yml          # instructions only — create secrets via kubectl
├── postgres/
│   ├── postgres-service.yml
│   └── postgres-deployment.yml     # PVC + StatefulSet
├── redis/
│   ├── redis-service.yml
│   └── redis-deployment.yml        # PVC + Deployment
├── migrate/
│   └── migrate-job.yml             # one-off Prisma migrate Job
├── api/
│   ├── api-service.yml
│   └── api-deployment.yml
└── ingress/
    └── ingress.yml

scopify-backend/secrets/              # real env files (gitignored)
├── postgres.env.example
├── api.env.example
└── .gitignore
```

**Image** is built from `Scopify Backend/backend/Dockerfile` and pushed to GHCR — not from docker-compose.

## Prerequisites

- Cluster ready (`ansible-playbook site.yml`)
- Ingress controller running (`kubectl get pods -n ingress-nginx`)
- Edge Nginx route for API host → Ingress NodePort (see `docs/SERVER_STRUCTURE.md`)
- Cloudflare A record for `api.ashmit.xyz` / `api-dev.ashmit.xyz` → Nginx EIP

## Secrets (never commit real values)

```bash
cp scopify-backend/secrets/postgres.env.example scopify-backend/secrets/prod-postgres.env
cp scopify-backend/secrets/api.env.example scopify-backend/secrets/prod-api.env
# edit both files with real passwords

kubectl apply -f scopify-backend/prod/namespace/

kubectl -n scopify-prod create secret generic scopify-postgres \
  --from-env-file=scopify-backend/secrets/prod-postgres.env

kubectl -n scopify-prod create secret generic scopify-api-env \
  --from-env-file=scopify-backend/secrets/prod-api.env
```

If GHCR image is private, create a pull secret once per namespace:

```bash
kubectl -n scopify-prod create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_GHCR_TOKEN
```

Then uncomment `imagePullSecrets` in `api/api-deployment.yml`.

## Apply order (prod)

Run from repo root on the **Master** node (or anywhere with kubeconfig):

```bash
cd k8s

kubectl apply -f scopify-backend/prod/namespace/
# secrets: see above

kubectl apply -f scopify-backend/prod/postgres/
kubectl apply -f scopify-backend/prod/redis/

kubectl wait -n scopify-prod --for=condition=ready pod -l app=postgres --timeout=180s
kubectl wait -n scopify-prod --for=condition=ready pod -l app=redis --timeout=120s

kubectl apply -f scopify-backend/prod/migrate/
kubectl wait -n scopify-prod --for=condition=complete job/scopify-migrate --timeout=300s

kubectl apply -f scopify-backend/prod/api/
kubectl apply -f scopify-backend/prod/ingress/

kubectl -n scopify-prod get pods,svc,ingress
curl -k https://api.ashmit.xyz/health   # after edge Nginx is wired
```

**Dev:** same commands with `scopify-backend/dev/` and namespace `scopify-dev`.

## Re-deploy API only (new image tag)

1. Build & push image (Dockerfile → GHCR).
2. Edit `image:` tag in `api/api-deployment.yml`.
3. If schema changed: `kubectl -n scopify-prod delete job scopify-migrate` then re-apply `migrate/`.
4. `kubectl apply -f scopify-backend/prod/api/`

## Move to Kustomize later

Refactor duplicated prod/dev folders into `base/` + `overlays/prod|dev/` — same files, less duplication.
