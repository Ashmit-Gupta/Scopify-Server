# Monitoring

Observability status for the Scopify platform.

---

## Current State

| Capability | Status |
|------------|--------|
| kube-prometheus-stack via Argo | **Designed, commented out** in `k8s/platform/monitoring/application.yml` |
| Grafana dashboards | Not active in Git |
| Alertmanager routes | Not configured |
| Centralized logging | `k8s/logging/` empty |
| Workload probes | **Active** in manifests |
| CI logs | Jenkins console |
| Edge logs | Nginx container/host |

Do not claim Prometheus/Grafana are production-live without screenshots.

---

## Prometheus

**Planned values (from commented Application):**

- Chart: `kube-prometheus-stack` targetRevision `72.6.2`
- Retention: 15d  
- PVC: 50Gi `gp3`  
- Ingress: disabled (keep UI internal unless Nginx host added)

**Why this chart:** Bundles Prometheus Operator, Grafana, Alertmanager, exporters — standard cluster landing zone.

**Cost:** Significant CPU/RAM/PVC on 2-worker lab — reason it remains optional.

---

## Grafana

**Planned:** Ingress host `grafana.ashmit.xyz`, admin password placeholder `CHANGE_ME`, PVC 10Gi.

TODO: Waiting for screenshot of Grafana once deployed.

---

## Metrics

**Available today without full stack:**

- kubelet/cadvisor (cluster-local)  
- Application `/health` (synthetic up/down)  

**Planned:** node-exporter, kube-state-metrics, ServiceMonitors from chart defaults.

---

## Alerting

Not configured. Target: Alertmanager PVC 10Gi; notification channel **TODO**.

Suggested first alerts (when enabled):

- Pod CrashLoopBackOff  
- PVC Pending > N minutes  
- Ingress 5xx rate  
- Node NotReady  
- Certificate expiry (edge Certbot)

---

## Logging

No EFK/Loki/CloudWatch agent in Terraform/Ansible reviewed.

Temporary approach: `kubectl logs`, Jenkins logs, `docker logs scopify-nginx`.

---

## Future Observability Improvements

1. Uncomment/apply monitoring Application with Secret-managed Grafana password  
2. Add `grafana.ashmit.xyz` to Cloudflare + verify Nginx upstream already covers via Ingress  
3. Loki or CloudWatch Logs  
4. Trace pipeline (OpenTelemetry) for NestJS  
5. SLO: `aws-api.ashmit.xyz/health` success rate  

[ Screenshot Required ]

**Description:** Prometheus → Status → Targets  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** Grafana dashboard  
**TODO:** Waiting for screenshot
