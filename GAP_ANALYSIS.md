# Gap analysis — frozen architecture vs Scopify Server

> Generated after renaming `gaming-board-*` → `scopify-*` in-repo (2026-07-13).  
> Design source: [`ARCHITECTURE.md`](./ARCHITECTURE.md)  
> Steps source: [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md)

---

## Rename status

| Item | In git | On AWS |
|------|--------|--------|
| `project_name = "scopify-cluster"` | Done | **Needs `terraform apply`** |
| SG names `scopify-*-sg` | Done | **Needs apply** (may recreate SGs) |
| Inventory `tag:Project: scopify-cluster` | Done | Empty until AWS tags updated |
| Docs paths `ansible/` / `terraform/` (not `project/…`) | Done | n/a |
| WSL path → Scopify Server | Done | n/a |

**Until you apply Terraform, running EC2s still have `Project=gaming-board-cluster` — Ansible inventory will find nothing with the new filter.**

---

## NOT missing (already have)

| Capability | Where |
|------------|--------|
| Terraform EC2 modules (instance + SG) | `terraform/modules/ec2`, `security-group` |
| 6-instance lab layout (master, 2 workers, jenkins, sonar, nexus) | `terraform.tfvars` |
| Default VPC data sources | `terraform/main.tf` |
| Ansible K8s bootstrap (kubeadm, Calico, ingress apply on master role) | `ansible/site.yml` + roles |
| Jenkins / Sonar / Nexus **on EC2 via Docker** | `ansible/site-tools.yml` + roles |
| Trivy on Jenkins host | `ansible/roles/trivy` |
| Dynamic EC2 inventory | `ansible/inventories/aws_ec2.yml` |
| Architecture + implementation docs | `ARCHITECTURE.md`, `IMPLEMENTATION_PLAN.md` |
| `.gitignore` (state, providers, tfvars) | root |
| Scopify naming in config (repo) | tfvars + inventory |

---

## Missing (required for frozen target)

### Networking / edge (Steps 2–6)

| Item | Status |
|------|--------|
| `modules/vpc` (subnets, IGW, NAT, route tables) | **Done in repo** — `use_custom_vpc = false` until migration |
| `modules/vpc-endpoints` | **Done in repo** — optional; **not required** with NAT |
| `modules/security-group` + `modules/ec2` | Already existed; still used |
| Nginx EIP association when instance key `nginx` exists | **Done in root main.tf** |
| Nginx EC2 + SG in live `terraform.tfvars` | **Missing** — add when ready |
| Ansible `nginx` role / TLS / DNS | **Missing** |
| Turn on `use_custom_vpc` + migrate running lab | **Not done** (destructive if flipped casually) |

### Kubernetes platform (Steps 7–8, 11–12)

| Missing | Why it matters |
|---------|----------------|
| `k8s/` or `helm/` folder | Manifests home |
| Documented Ingress Controller install (values/manifests in repo) | Edge → pods |
| In-cluster **SonarQube** Helm/manifests + PVC | Move off EC2 |
| In-cluster **Nexus** Helm/manifests + PVC | Move off EC2 |
| Prometheus / Grafana stack | Observability hostnames |
| Argo CD install + Application manifests | GitOps |
| NetworkPolicies (optional hardening) | Pod isolation |

### Scopify product on cluster (Step 10)

| Missing | Why it matters |
|---------|----------------|
| `k8s/scopify/` Deployment / Service / Ingress | `api.ashmit.xyz` |
| Postgres + Redis for API (Helm or external) | Runtime deps |
| Secrets management pattern (Sealed Secrets / External Secrets / documented kubectl) | JWT, DB, Resend |
| Scopify UI manifests | `app.ashmit.xyz` (UI not in monorepo yet) |

### CI wiring (cross-repo, still missing)

| Missing | Why it matters |
|---------|----------------|
| Backend `Jenkinsfile` | Pipeline as code |
| Jenkins → kubeconfig / deploy credentials docs | kubectl from Jenkins |
| Image push to in-cluster Nexus (after Step 9) | Registry path |

### Cleanup after migration

| Missing | Why it matters |
|---------|----------------|
| Terraform without `sonar` / `nexus` EC2s | End-state instance set = nginx + jenkins + 3 k8s |
| `site-tools.yml` Jenkins-only | Stop managing Sonar/Nexus EC2 containers |
| `custom-ansible` Dockerfile in this repo | Docs still assume image; not present here |

---

## Partial / ambiguous

| Item | Status |
|------|--------|
| “Ingress” in master Ansible role | Likely NGINX Ingress manifests applied at kubeadm time — **verify** on cluster; not the same as repo-managed Ingress + host routing via edge Nginx |
| Sonar/Nexus | **Present on EC2**, **missing in K8s** (target is K8s) |
| Public IPs on all nodes | Present (lab); target wants private (except Nginx) |
| World-open SGs (`0.0.0.0/0`) | Present; target wants lockdown |

---

## Checklist vs implementation steps

| Step | Status |
|------|--------|
| 0 Prep / inventory | Ops — do manually |
| 1 Rename | **Repo done** — AWS apply pending |
| 2 Nginx + EIP Terraform | Missing |
| 3 Ansible Nginx | Missing |
| 4 DNS | Missing (Squarespace) |
| 5 TLS | Missing |
| 6 SG lockdown | Missing (needs SG-source support) |
| 7 Ingress Controller (repo-managed) | Missing / verify existing |
| 8 Nginx → Ingress | Missing |
| 9 Sonar/Nexus in K8s + retire EC2 | Missing |
| 10 Scopify API/UI on K8s | Missing |
| 11 Prometheus/Grafana | Missing |
| 12 Argo CD | Missing |
| 13 Private VPC + NAT | Missing |
| 14 Route53 + ALB | Deferred |

---

## Bottom line

**Not missing:** working flat lab (6 EC2s, K8s, Jenkins/Sonar/Nexus on VMs, Ansible/Terraform, docs, Scopify rename in git).

**Missing for frozen arch:** Nginx+EIP edge, DNS/TLS, SG lockdown, VPC/private design, in-cluster Sonar/Nexus/Scopify/observability/Argo, and retiring tool EC2s.

**Next concrete action:** `terraform plan/apply` for rename tags (careful with SG renames), then Step 2 — add Nginx + EIP.
