# ADR-005: Argo CD for continuous delivery

- **Status:** Accepted  
- **Evidence:** Jenkinsfile GitOps comments; PreSync hooks; `argocd-ingress.yaml`; ARCHITECTURE §5.5

## Context

After images exist, the cluster must converge to a declared state without Jenkins retaining long-lived cluster mutate authority.

## Decision

Use **Argo CD** to sync Kustomize app trees from Scopify-Server. Jenkins only builds/pushes images and commits manifest tag bumps.

## Alternatives

| Option | Notes |
|--------|-------|
| Jenkins `kubectl apply` | Faster lab; weak drift detection |
| Flux | Equally valid GitOps; Argo UI preferred for learning |
| Helm-only CD from CI | Mixes build and reconcile |

## Tradeoffs

- **+** Audit trail in Git; drift detection; PreSync migrations  
- **−** Extra platform component to secure/expose (`argocd.ashmit.xyz`)  
- **−** Dual-repo write access from CI  

## Consequences

Application CRs and RBAC must be maintained. Rollback prefers Git revert.
