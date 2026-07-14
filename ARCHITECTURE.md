# Scopify AWS DevOps Lab — Frozen Target Architecture

> **Status:** FROZEN target design (decision record)  
> **Domain:** `ashmit.xyz` (Squarespace today → Cloudflare DNS/WAF/CDN; Route 53 optional later)  
> **Region:** `ap-south-1` (Mumbai)  
> **Owner:** Ashmit  
> **Last updated:** 2026-07-13  
>
> This document is the source of truth for where the lab is going.  
> Current Terraform/Ansible still implement an older flat design — see [§8 Migration](#8-migration-from-current-lab).  
> **How to get here (ordered steps):** [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

---

## 1. Purpose

Personal DevOps learning environment that also hosts **Scopify** (API + UI) with a realistic CI/CD and Kubernetes path:

- One public entry point (cost + security)
- Host-based routing + TLS on Nginx
- Private workloads (Jenkins EC2 + Kubernetes)
- Progressive evolution toward Ingress, ArgoCD, and later AWS ALB

---

## 2. Frozen architecture (canonical)

### 2.1 End-to-end network diagram

> **Sketch vs Terraform:** Diagram uses simple `10.0.0.0/16` + `/24` examples.  
> Live `terraform.tfvars` uses **`vpc_cidr = "10.20.0.0/16"`** with public/private subnets across **2 AZs** (`/20`s). Same layout, different numbers.  
> **SSM:** Admin access to private EC2s is via Session Manager (not shown as a user→SSH path below).  
> **Today vs target:** Sonar/Nexus may still be private EC2s until moved into the cluster (diagram shows final in-cluster placement).

```
                                           USER
                                            │
                                            │
                                   https://ashmit.xyz
                                            │
                                            ▼
                                    Squarespace DNS
                                            │
                             A Record -> Elastic IP
                                            │
                                            ▼
════════════════════════════════ INTERNET ════════════════════════════════
                                            │
                                            ▼
                                  Elastic IP (Nginx)
                                            │
                                            ▼
                               AWS INTERNET GATEWAY (IGW)
                                            │
══════════════════════════════════════════════════════════════════════════
                        CUSTOM VPC (10.0.0.0/16)
══════════════════════════════════════════════════════════════════════════

                     PUBLIC ROUTE TABLE
              0.0.0.0/0  ─────► Internet Gateway

        ┌─────────────────────────────────────────────┐
        │                                             │
        │        PUBLIC SUBNET (10.0.1.0/24)          │
        │                                             │
        │  ┌───────────────────────────────────────┐  │
        │  │ Nginx EC2                             │  │
        │  │---------------------------------------│  │
        │  │ Reverse Proxy                         │  │
        │  │ SSL Termination                       │  │
        │  │ Host Routing                          │  │
        │  │ Access Logs                           │  │
        │  └───────────────────────────────────────┘  │
        │                     │                        │
        │                     │                        │
        │                     ▼                        │
        │         ┌────────────────────────┐           │
        │         │ NAT Gateway            │           │
        │         │ (Own Elastic IP)       │           │
        │         └────────────────────────┘           │
        │                                             │
        └─────────────────────────────────────────────┘
                              │
                              │
══════════════════════════════════════════════════════════════════════════

                    PRIVATE ROUTE TABLE
              0.0.0.0/0  ─────► NAT Gateway

        ┌─────────────────────────────────────────────┐
        │                                             │
        │      PRIVATE SUBNET (10.0.2.0/24)           │
        │                                             │
        │  ┌───────────────────────────────────────┐  │
        │  │ Jenkins EC2                           │  │
        │  │---------------------------------------│  │
        │  │ Jenkins Master                        │  │
        │  │ Docker                                │  │
        │  │ kubectl                               │  │
        │  │ Helm                                  │  │
        │  └───────────────────────────────────────┘  │
        │                     │                        │
        │                     │                        │
        │                     ▼                        │
        │  ┌───────────────────────────────────────┐  │
        │  │ Kubernetes Control Plane              │  │
        │  │---------------------------------------│  │
        │  │ API Server                            │  │
        │  │ Scheduler                             │  │
        │  │ Controller Manager                    │  │
        │  │ etcd                                  │  │
        │  └───────────────────────────────────────┘  │
        │                     │                        │
        │        ┌────────────┴─────────────┐          │
        │        ▼                          ▼          │
        │ ┌──────────────┐         ┌──────────────┐    │
        │ │ Worker Node 1│         │ Worker Node 2│    │
        │ └──────────────┘         └──────────────┘    │
        │        │                          │          │
        │        └────────────┬─────────────┘          │
        │                     ▼                        │
        │          Kubernetes Scheduler                │
        │                     │                        │
        │    ┌────────────────┼─────────────────┐      │
        │    ▼                ▼                 ▼      │
        │ Scopify API     Scopify UI        ArgoCD     │
        │                                              │
        │ SonarQube                                    │
        │ Nexus                                        │
        │ Prometheus                                   │
        │ Grafana                                      │
        │                                              │
        └─────────────────────────────────────────────┘

══════════════════════════════════════════════════════════════════════════

                    AWS EBS VOLUMES / PERSISTENCE

        Jenkins Volume          (EC2 root or dedicated EBS — lab: root today)

        SonarQube Volume        (EC2 now → PVC when in-cluster)

        Nexus Volume            (EC2 now → PVC when in-cluster)

        Prometheus Volume       (K8s PVC)

        Kubernetes Persistent Volumes
══════════════════════════════════════════════════════════════════════════
```

### 2.2 Compact flow (summary)

```
Internet → ashmit.xyz → Squarespace → EIP → IGW → Nginx (public)
                                              │
                              host-based proxy + TLS
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
              Jenkins EC2              K8s Ingress / NodePorts     (future hosts)
              (private)                (private workers)
                    │
                    └── kubectl / Helm → control plane → workers → apps
```

### 2.3 Edge with Cloudflare (DNS + WAF + CDN)

Target / preferred public edge path (can replace or sit in front of Squarespace DNS):

```
Internet
      │
      ▼
Cloudflare
(DNS + WAF + CDN)
      │
      ▼
Elastic IP
      │
      ▼
Nginx EC2
      │
      ├────► Jenkins
      └────► Kubernetes
```

**How to read this**

| Hop | Role |
|-----|------|
| Cloudflare | DNS for `ashmit.xyz` / subdomains; optional WAF + CDN/proxy (orange cloud) |
| Elastic IP | Stable address of the Nginx EC2 (only public AWS entry) |
| Nginx EC2 | TLS (or Cloudflare-terminated), host-based reverse proxy |
| Jenkins | Private EC2 (CI) — e.g. `jenkins.ashmit.xyz` |
| Kubernetes | Private cluster — API apps, Sonar, Nexus, Grafana, ArgoCD via Ingress later |

**Squarespace vs Cloudflare:** Phase docs still mention Squarespace where the domain lives today. Moving DNS (and enabling proxy/WAF) to **Cloudflare** is the intended edge upgrade; A/AAAA (or CNAME flattening) still point at the **same Nginx EIP**.

### Design locks (do not casually change)

| Lock | Decision |
|------|----------|
| Public edge | **Only** Nginx EC2 has Elastic IP + internet-facing SG |
| DNS | All app/tool subdomains → **same EIP** (via Squarespace **or** Cloudflare) |
| CDN / WAF | Prefer **Cloudflare** in front of Nginx when ready (§2.3) |
| CI | Jenkins stays on **dedicated EC2** (not in-cluster initially) |
| Runtime | Apps + Sonar + Nexus + observability + ArgoCD run **in Kubernetes** |
| Registry / artifacts | Nexus in-cluster with **PVC** |
| DNS provider | Squarespace today → migrate to Cloudflare (§2.3); Route 53 optional later |
| AWS LB (Phase 1–2) | **No ALB/NLB** yet — learn Nginx + Ingress first |

---

## 3. Network model

### 3.1 Subnets

| Tier | Contents | Internet |
|------|----------|----------|
| **Public subnet** | Nginx (+ IGW route) | Inbound 80/443 from Internet; EIP attached |
| **Private subnet(s)** | Jenkins, K8s master, workers | No public IPs; no direct inbound from Internet |

### 3.2 Outbound from private tier (required)

Private instances need outbound internet for package/image pulls (Docker Hub, GHCR, apt, Helm charts).

| Approach | When to use | Cost |
|----------|-------------|------|
| **NAT Gateway** (preferred for “real” private design) | When freezing true private subnets | ~$32+/mo — accept when ready |
| Temporary hybrid: private *security* via SG only, instances still in public subnet without world-open ports | Cheap learning bridge | Low |

**Frozen intent:** true public/private split + NAT when cost allows. Until then, document any hybrid as temporary.

### 3.3 Security groups (target)

| Component | Inbound allow |
|-----------|----------------|
| Nginx | `0.0.0.0/0` :80, :443 (and SSH from admin IP / SSM preferred) |
| Jenkins | **Nginx SG only** :8080; SSH/SSM from admin; K8s API access as needed |
| K8s nodes | From Jenkins SG (6443); from Nginx SG (Ingress NodePort / 80–443 on nodes); node-to-node as required by kubeadm |
| Pods | Cluster networking + NetworkPolicies later |

No Sonar/Nexus **EC2** SGs in the end state — those move into the cluster.

### 3.4 Elastic IP

- Exactly **one** EIP, associated with Nginx.
- Attached EIP on a running instance is typically free; unused EIPs are billed.
- Solves “IP changes on stop/start” for everything users hit via DNS.

---

## 4. DNS map (`ashmit.xyz`)

All records are **A** (or CNAME→A / Cloudflare flattening) pointing at the **Nginx Elastic IP**.  
DNS may be hosted on **Squarespace** (current) or **Cloudflare** (§2.3 — preferred for WAF/CDN).

| Hostname | Proxied to | Notes |
|----------|------------|--------|
| `jenkins.ashmit.xyz` | Jenkins EC2 private IP `:8080` | CI UI |
| `sonar.ashmit.xyz` | K8s Ingress → SonarQube Service | In-cluster |
| `nexus.ashmit.xyz` | K8s Ingress → Nexus Service | Docker/raw repos; PVC |
| `api.ashmit.xyz` | K8s Ingress → Scopify API | NestJS backend |
| `app.ashmit.xyz` (or `www`) | K8s Ingress → Scopify UI | Frontend (when built) |
| `grafana.ashmit.xyz` | K8s Ingress → Grafana | Observability |
| `prometheus.ashmit.xyz` | K8s Ingress → Prometheus | Optional expose; often internal-only in prod |
| `argocd.ashmit.xyz` | K8s Ingress → Argo CD | GitOps UI |

Nginx inspects the `Host` header and either:

1. `proxy_pass` to Jenkins private IP, or  
2. `proxy_pass` to the **Ingress Controller** (NodePort/LoadBalancer-internal) for everything in Kubernetes.

TLS: terminate on Nginx with Let’s Encrypt (Certbot) for these hostnames in Phase 1. Later, cert-manager inside the cluster is optional.

---

## 5. Component responsibilities

### 5.1 Nginx (edge)

- Sole public reverse proxy
- TLS certificates for `*.ashmit.xyz` hostnames in use
- Host-based virtual hosts
- Optional: rate limiting, basic auth for Grafana/Prometheus later

### 5.2 Jenkins (private EC2)

- CI pipelines for `scopify-backend` (and later UI)
- Stages: checkout → test → Sonar scan → Docker build → Trivy → push to Nexus/GHCR → deploy via **kubectl/Helm** (or hand off to Argo CD)
- Has Docker + Trivy (already provisioned by Ansible in current lab)
- Needs network path to K8s API and to Nexus registry

### 5.3 Kubernetes cluster

| Workload | Type | Persistence |
|----------|------|-------------|
| Scopify API | Deployment + Service | Stateless; secrets for DB/JWT/Redis |
| Scopify UI | Deployment + Service | Stateless |
| SonarQube | StatefulSet/Helm | PVC (DB/data) |
| Nexus | StatefulSet/Helm | **PVC** (artifacts/images) |
| Prometheus | Helm (e.g. kube-prometheus-stack) | PVC |
| Grafana | Same stack / Helm | PVC or config via ConfigMap |
| Argo CD | Helm | GitOps control plane |

**Control plane:** kubeadm master (current lab).  
**Data plane:** worker-1, worker-2. Scheduler places pods per requests/limits and affinities.

### 5.4 Scopify product (runtime on K8s)

- **API:** NestJS, Prisma, Postgres, Redis, Resend (env via Secrets)
- **UI:** not in repo yet — planned front door via `app.ashmit.xyz`
- Images: built by Jenkins, stored in Nexus (and/or GHCR)

### 5.5 Argo CD (GitOps)

- Desired end state for K8s apps from a Git repo (Server and/or Backend deploy manifests)
- Jenkins can build/push images and update a tag in Git; Argo syncs the cluster
- Alternative interim: Jenkins `kubectl apply` until Argo is installed

---

## 6. Request flows

### 6.1 Human opens Jenkins

```
Browser → https://jenkins.ashmit.xyz
       → Squarespace A → EIP
       → Nginx :443 (SNI/Host)
       → http://<jenkins-private-ip>:8080
```

### 6.2 Human opens Sonar / Nexus / API / Grafana

```
Browser → https://sonar.ashmit.xyz (example)
       → EIP → Nginx :443
       → Ingress Controller (private)
       → Service → Pod
```

### 6.3 CI deploy path

```
Dev push → GitHub (scopify-backend)
        → Jenkins Pipeline
        → SonarQube (in-cluster)
        → Build image → Nexus (in-cluster PVC)
        → Trivy
        → kubectl/Helm  OR  Git commit → Argo CD sync
        → Pods on Worker 1 / Worker 2
```

---

## 7. Evolution phases (approved ladder)

### Phase 0 — Current lab (as-built today)

- Default VPC, public IPs on 6 EC2s  
- Separate EC2s: Jenkins, Sonar, Nexus, Master, Worker×2  
- No Nginx EIP edge, no private subnet split  
- Tools reachable on public IPs :8080 / :9000 / :8081  

### Phase 1 — Edge + DNS (next infra freeze step)

```
DNS → EIP → Nginx (public) → private IPs of today’s EC2 tools + Ingress later
```

Learn: DNS, EIP, Nginx, TLS, SG lockdown.

### Phase 2 — Workloads into Kubernetes

- Move Sonar + Nexus **off EC2 into cluster** (PVCs)  
- Deploy Scopify API (+ UI)  
- Install Ingress Controller; Nginx proxies app hostnames to Ingress  
- Add Prometheus, Grafana, Argo CD  

### Phase 3 — AWS-native load balancing (later)

```
Route 53 → ALB → Kubernetes (AWS Load Balancer Controller)
```

Learn: ALB, target groups, listener rules. **Not** preferred until Nginx + Ingress are mastered. Extra cost.

---

## 8. Migration from current lab

| Today | Frozen target |
|-------|----------------|
| 6 public EC2s | Nginx public + Jenkins private + 3 K8s nodes private |
| Sonar/Nexus on EC2 | Sonar/Nexus **in K8s** + PVC |
| Direct IP:port access | Only `*.ashmit.xyz` via Nginx |
| Naming | Repo uses `scopify-cluster` / `scopify-*-sg` — run `terraform apply` to sync AWS |
| No Ingress / Argo / observability stack | Required in Phase 2 |

**Suggested order of implementation**

1. Terraform: custom VPC (public + private), Nginx instance, EIP, NAT (or documented hybrid)  
2. DNS A records for needed hostnames → EIP  
3. Nginx configs + Certbot  
4. SG lockdown (remove world-open tool ports)  
5. Install Ingress in cluster; point app hostnames at it  
6. Helm install Nexus + Sonar in-cluster; migrate data; decommission Sonar/Nexus EC2s  
7. Scopify API manifests + Jenkinsfile push/deploy  
8. kube-prometheus-stack + Argo CD  
9. Scopify UI when ready  

---

## 9. Cost & learning guardrails

| Do | Don’t |
|----|--------|
| One EIP on Nginx | EIP on every instance |
| Destroy / stop lab when idle | Leave 6× large instances 24/7 unused |
| Expose Grafana/Prometheus carefully | Open K8s API `:6443` to `0.0.0.0/0` long-term |
| Accept single Nginx SPOF in lab | Pretend lab has HA |
| Add NAT when going fully private | Assume private instances work with zero outbound path |

---

## 10. Related repos

| Repo | Role in this architecture |
|------|---------------------------|
| [Scopify-Server](https://github.com/Ashmit-Gupta/Scopify-Server) | Terraform, Ansible, future Nginx/Ingress/Helm docs |
| [scopify-backend](https://github.com/Ashmit-Gupta/scopify-backend) | NestJS API, Dockerfile, Jenkinsfile, GHCR workflow |
| Scopify UI (future) | Front-end image + Ingress |

---

## 11. Decision record

| Date | Decision |
|------|----------|
| 2026-07-12 | Reject EIP-per-EC2; prefer single public entry |
| 2026-07-13 | **Freeze** architecture: Nginx public edge; Jenkins private EC2; apps + Sonar + Nexus + observability + ArgoCD on Kubernetes; DNS `ashmit.xyz` → one EIP |
| 2026-07-13 | Add Cloudflare edge path (DNS + WAF + CDN) → EIP → Nginx → Jenkins / Kubernetes (§2.3) |

**Change control:** Update this file when the frozen design changes. Do not silently diverge Terraform from this doc without a migration note in §8.

---

## 12. ASCII ops checklist (target reached when…)

- [ ] `dig jenkins.ashmit.xyz` → Nginx EIP  
- [ ] HTTPS works for jenkins/sonar/nexus/api (and others as added)  
- [ ] Jenkins, K8s nodes have **no** public inbound except via Nginx/admin path  
- [ ] Sonar + Nexus pods healthy with PVCs  
- [ ] Scopify API reachable at `api.ashmit.xyz`  
- [ ] Jenkins can build, push to Nexus, deploy (or Argo syncs)  
- [ ] Grafana/Prometheus/ArgoCD reachable via their hostnames (or intentionally internal)  

---

*End of frozen architecture document.*
