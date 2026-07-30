# GitOps Flow

## Purpose

Explain how Git becomes the desired-state API for Kubernetes, and how Jenkins participates without becoming the cluster mutator of record.

## Architecture

```
Scopify-Server Git (main)
  k8s/scopify-backend/dev/kustomization.yaml
  k8s/scopify-backend/prod/kustomization.yaml
            │
            ▼
     Argo CD Applications
     (point at those paths — exact Application CRs not committed as active YAML)
            │
            ▼
     Kubernetes API
            │
            ├── PreSync: scopify-migrate Job
            └── Sync: Deployments/Services/Ingress/…
```

Migrate Job annotations (prod/dev):

- `argocd.argoproj.io/hook: PreSync`
- `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation`

## Flow

1. Manifest image tag changes in Git (Jenkins or human PR).
2. Argo detects difference vs live cluster (polling or webhook — **TODO:** confirm live config).
3. Sync starts → PreSync migrate Job must succeed.
4. Workloads apply; health checks evaluated.
5. Drift (UI/kubectl edits) can self-heal if automated sync + selfHeal enabled on Application.

## Components

Kustomize entrypoints, gitignored secrets (out of band), Argo Ingress `argocd.ashmit.xyz`, edge Nginx upstream to NodePort.

## Tradeoffs

| Approach | Pros | Cons |
|----------|------|------|
| Manifest bump in same Server repo | Simple for one owner | CI needs write access to infra repo |
| Helm umbrella | Packaged deps | More abstraction than needed for small API |
| Jenkins kubectl apply | Faster lab | Bypasses Git history / drift detection |

## Future Improvements

- Commit Argo `Application` manifests for scopify-dev/prod (App-of-Apps)
- PR-based promotion (dev image → prod) instead of dual branch build
- Sync windows / manual sync for prod

## Diagram

[ Screenshot Required ]

**Description:** Argo CD UI — Applications list + sync status  
**Purpose:** Prove GitOps operational  
**TODO:** Waiting for screenshot
