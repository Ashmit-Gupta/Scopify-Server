# Observability Flow

## Purpose

State what observability exists today versus what is designed but not activated.

## Architecture

**Designed (commented):** Argo Application `k8s/platform/monitoring/application.yml` for `kube-prometheus-stack` chart `72.6.2` into namespace `monitoring`, with:

- Grafana Ingress `grafana.ashmit.xyz`, PVC `gp3` 10Gi
- Prometheus retention 15d, PVC 50Gi, Ingress disabled
- Alertmanager PVC 10Gi, Ingress disabled
- nodeExporter + kubeStateMetrics enabled in values sketch
- Automated sync + ServerSideApply + webhook CA ignoreDifferences

**As-built in Git:** file is fully commented — **not an active Application**.

**Partial signals today:**

- Kubernetes probes on API (`/health`), Postgres (`pg_isready`), Redis (`PING`)
- Jenkins build logs
- Nginx access/error logs on edge host
- Trivy reports in CI console

**Logging stack:** `k8s/logging/` directory exists but is empty — no EFK/Loki manifests yet.

## Flow (target)

```
Pods / nodes → ServiceMonitors / exporters
            → Prometheus
            → Alertmanager → (TODO notification channel)
            → Grafana dashboards
```

## Components

Planned: Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter.  
Present: probe endpoints, CI logs, edge logs.

## Tradeoffs

Delaying full stack reduces PVC/CPU cost on small workers; incidents rely on kubectl + Jenkins until enabled.

## Future Improvements

- Uncomment/apply monitoring Application with real Grafana password via Secret
- Add Loki or CloudWatch agent
- Alert on CrashLoopBackOff, PVC pending, 5xx at edge
- Synthetic check for `https://aws-api.ashmit.xyz/health`

## Diagram

[ Screenshot Required ]

**Description:** Grafana home + Prometheus targets (once deployed)  
**TODO:** Waiting for screenshot — stack not confirmed active
