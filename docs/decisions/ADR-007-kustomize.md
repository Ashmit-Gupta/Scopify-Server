# ADR-007: Kustomize for application manifests

- **Status:** Accepted  
- **Evidence:** `k8s/scopify-backend/{dev,prod}/kustomization.yaml`; k8s README

## Context

Need env parity (dev/prod) without heavy templating for a single API + dependencies.

## Decision

Use **plain YAML + Kustomize** roots per environment. Secrets intentionally omitted from `resources:` lists.

## Alternatives

| Option | Notes |
|--------|-------|
| Helm chart for Scopify | Better for third-party reuse; more boilerplate now |
| Raw kubectl folders only | Works; weaker composition entrypoint for Argo |
| Jsonnet/CDK8s | Overkill for current size |

## Tradeoffs

- **+** Readable diffs; Argo native detection  
- **−** Duplication between dev/prod trees (accepted for clarity)  
- **−** No value schema validation like Helm  

## Consequences

Jenkins sed updates duplicated paths per env. Future: Kustomize overlays to DRY images/names.
