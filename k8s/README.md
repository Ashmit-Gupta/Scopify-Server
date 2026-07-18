# Kubernetes manifests — Scopify Server

Plain YAML (no Kustomize). Two environments as separate folders:

| Folder | Namespace | Ingress host |
|--------|-----------|--------------|
| `scopify-backend/prod/` | `scopify-prod` | `api.ashmit.xyz` |
| `scopify-backend/dev/` | `scopify-dev` | `api-dev.ashmit.xyz` |

## Folder layout (prod and dev mirror each other)

```
scopify-backend/prod/   (dev/ is the same)
├── namespace/
│   └── namespace.yml
├── secrets/
│   ├── postgres-secret.yml.example   # template (committed)
│   ├── api-secret.yml.example        # template (committed)
│   ├── postgres-secret.yml           # real values (gitignored)
│   └── api-secret.yml                # real values (gitignored)
├── postgres/
├── redis/
├── migrate/
├── api/
└── ingress/
```

**Image** is built from `Scopify Backend/backend/Dockerfile` and pushed to GHCR.

## Secrets (copy example → real file, then apply)

```bash
cd k8s/scopify-backend/dev/secrets

cp postgres-secret.yml.example postgres-secret.yml
cp api-secret.yml.example api-secret.yml
# edit CHANGE_ME_* in both files (same password in POSTGRES_PASSWORD and DATABASE_URL)

kubectl apply -f ../namespace/
kubectl apply -f postgres-secret.yml
kubectl apply -f api-secret.yml
```

Same for `prod/secrets/`. Real `*-secret.yml` files are gitignored.

Jenkins does **not** apply secrets (avoids applying examples). Create them once before the first deploy.

## Apply order (dev)

```bash
cd k8s

kubectl apply -f scopify-backend/dev/namespace/
# secrets: see above (required once)

kubectl apply -f scopify-backend/dev/postgres/
kubectl apply -f scopify-backend/dev/redis/
# … then migrate, api, ingress (or let Jenkins Deploy do the rest)
```

If GHCR image is private, create `ghcr-pull` and uncomment `imagePullSecrets` in `api/api-deployment.yml`.
