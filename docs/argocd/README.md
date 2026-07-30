# Argo CD

GitOps continuous delivery for Scopify Kubernetes workloads.

---

## GitOps Workflow

```
Git (Scopify-Server) ──desired──► Argo CD ──reconcile──► Kubernetes
         ▲
         │ image tag bump
      Jenkins CI
```

Canonical app paths:

- `k8s/scopify-backend/dev`
- `k8s/scopify-backend/prod`

Each directory has a root `kustomization.yaml` (secrets excluded).

---

## Repositories

| Repo | Role |
|------|------|
| Scopify-Server | Manifests Argo watches |
| scopify-backend | Not watched for deploy; only builds images |
| prometheus-community Helm (planned) | Commented monitoring Application source |

TODO: Waiting for screenshot of Argo → Settings → Repositories.

---

## Sync Strategy

Intended for apps (per `k8s/README.md`): Application points at env folder; Kustomize detected automatically.

**Exact live Application CR fields (auto-sync on/off, prune, selfHeal):**

TODO: Waiting for project details — Application manifests for scopify-dev/prod are not committed as active YAML in-repo (only monitoring sketch, commented).

Migrate Job participates via hooks:

```yaml
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

Ensures `prisma migrate deploy` runs before Deployment sync; old Job deleted so template/immutability updates succeed.

---

## Auto Sync

Designed in monitoring Application sketch (`automated.prune` + `selfHeal`).  

TODO: Confirm whether scopify Applications use automated sync.

---

## Manual Sync

Use Argo UI or CLI when auto sync off / for prod gated deploys.

TODO: Waiting for screenshot of Sync panel.

---

## Application Structure

**Present in Git:**

- Ingress for Argo UI: `k8s/platform/argocd/argocd-ingress.yaml` → `argocd.ashmit.xyz`  
- Edge Nginx server block for `argocd.ashmit.xyz`  
- App workloads under `k8s/scopify-backend/*`  
- Commented `kube-prometheus-stack` Application  

**Install method for Argo CD control plane:**

TODO: Waiting for project details (Helm install command / version pin used on cluster).

---

## Rollback

Argo History → Rollback to previous ReplicaSet/manifest revision, **or** `git revert` of manifest commit (preferred for audit).

---

## Drift Detection

Argo compares live objects to Git. UI kubectl edits create OutOfSync; with `selfHeal`, Argo reverts.

---

## Health Checks

Argo health + K8s probes (`/health`, `pg_isready`, Redis PING). PreSync Job failure blocks sync progression.

---

## Screenshots

[ Screenshot Required ]

**Description:** Argo CD Applications list (Healthy/Synced)  
**Purpose:** Prove GitOps operational  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** Application → Resource tree including PreSync Job  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** Diff view after Jenkins manifest bump  
**TODO:** Waiting for screenshot

---

## Related

- [architecture/gitops-flow.md](../architecture/gitops-flow.md)  
- [ADR-005](../decisions/ADR-005-argocd.md)  
- [ADR-007 Kustomize](../decisions/ADR-007-kustomize.md)
