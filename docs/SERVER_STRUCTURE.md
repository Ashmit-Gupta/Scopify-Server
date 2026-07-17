# Scopify Server — Detailed Structure & Context

> **What this document is:** A full walkthrough of how the Scopify Server lab is built, layer by layer — what each piece is, why it exists, and how it connects.  
> **Companion diagram:** [`docs/Scopify-Server-Architecture.drawio`](./Scopify-Server-Architecture.drawio) (open in [diagrams.net](https://app.diagrams.net)).  
> **Region:** `ap-south-1` (Mumbai) · **Project tag:** `scopify-cluster` · **Domain:** `ashmit.xyz`

---

## 1. Big picture — what “Scopify Server” actually is

**Scopify Server** is not one application. It is a **personal DevOps platform** that:

1. Hosts CI/CD tools (Jenkins, SonarQube, Nexus)
2. Runs a **Kubernetes cluster** (kubeadm on EC2)
3. Exposes everything through **one public edge** (Nginx + Cloudflare DNS + TLS)
4. Will eventually host the **Scopify product API** (NestJS) on that cluster

Two tools own different jobs:

| Tool | Job | Analogy |
|------|-----|---------|
| **Terraform** | Build the AWS skeleton (VPC, subnets, EC2, SGs, EIP, IAM) | Architect builds the building |
| **Ansible** | Install and configure software *on* those EC2s | Interior fit-out (OS, Docker, kubeadm, Nginx, Jenkins…) |

Terraform does **not** install Kubernetes. Ansible does **not** create the VPC. They chain:

```
terraform apply
        │
        ▼
   AWS resources exist (empty Ubuntu VMs in a private/public VPC)
        │
        ▼
ansible-playbook site.yml / site-tools.yml / site-nginx.yml
        │
        ▼
   Working cluster + tools + public HTTPS edge
```

---

## 2. Repo layout (where things live)

```
Scopify Server/
├── terraform/                 # IaC — create AWS infrastructure
│   ├── main.tf                # Wires modules: vpc, endpoints, iam-ssm, sg, ec2, eip
│   ├── terraform.tfvars       # YOUR live choices (CIDRs, instance map, SG rules)
│   ├── modules/
│   │   ├── vpc/               # Custom VPC, subnets, IGW, NAT, route tables
│   │   ├── vpc-endpoints/     # SSM + S3 (and optional ECR/logs) endpoints
│   │   ├── iam-ssm/           # Instance profile for Session Manager
│   │   ├── security-group/    # One SG per map key
│   │   └── ec2/               # One EC2 per instances{} entry
│   └── outputs.tf             # nginx_eip, private IPs, SSM connect hints…
│
├── ansible/                   # Config management — software on the VMs
│   ├── inventories/aws_ec2.yml# Discovers EC2 by AWS tags (no static IP lists)
│   ├── group_vars/            # Shared + per-role variables (versions, domain, secrets)
│   ├── site.yml               # Kubernetes bootstrap
│   ├── site-tools.yml         # Jenkins / Sonar / Nexus
│   ├── site-nginx.yml         # Edge reverse proxy + TLS
│   ├── site-ssm.yml           # SSM sessions land as ubuntu
│   └── roles/                 # common, master, workers, nginx, jenkins, …
│
├── docs/                      # Architecture diagrams & structure docs
├── Jenkinsfile                # Starter pipeline (checkout + echo testing)
├── ARCHITECTURE.md            # Frozen *target* design decision record
└── IMPLEMENTATION_PLAN.md     # Ordered steps toward the frozen target
```

**Mental model:**  
`ARCHITECTURE.md` = where you are *going*.  
`terraform.tfvars` + Ansible playbooks = what is *running today*.

---

## 3. Layer 1 — Networking (Terraform VPC)

### 3.1 Why a custom VPC?

Earlier lab versions used the **default VPC** (everything public, simple, insecure). The frozen design uses a **custom VPC** so that:

- Only **Nginx** is on the internet
- Tools and Kubernetes nodes have **no public IP**
- Outbound package/image pulls still work via a **NAT Gateway**
- Admin access uses **SSM** (or SSH jump through Nginx), not world-open SSH on every box

Live settings (`terraform.tfvars`):

| Setting | Value | Meaning |
|---------|-------|---------|
| `use_custom_vpc` | `true` | Use `modules/vpc`, not default VPC |
| `vpc_cidr` | `10.20.0.0/16` | Whole address space for the lab |
| `vpc_az_count` | `2` | Two availability zones |
| `enable_nat_gateway` | `true` | Private → internet for apt/Docker/GHCR |
| `enable_ssm` | `true` | Session Manager without bastion |
| `enable_ssm_vpc_endpoints` | `true` | SSM API reachable privately |

### 3.2 Subnets (how the CIDR is sliced)

Module uses `cidrsubnet(vpc_cidr, 4, i)` → each subnet is a **/20**:

| Tier | Index | Example CIDR | Role |
|------|-------|--------------|------|
| Public AZ-a | 0 | `10.20.0.0/20` | Nginx, NAT Gateway |
| Public AZ-b | 1 | `10.20.16.0/20` | Spare public capacity |
| Private AZ-a | 2 | `10.20.32.0/20` | Master, worker-1, tools (typical) |
| Private AZ-b | 3 | `10.20.48.0/20` | worker-2, extra private |

### 3.3 Routing

```
PUBLIC subnet route table:
  0.0.0.0/0  →  Internet Gateway (IGW)
  → Nginx can accept 80/443 from the world
  → NAT Gateway lives here so it can reach the internet

PRIVATE subnet route table:
  0.0.0.0/0  →  NAT Gateway
  → Private EC2s can download packages/images
  → Nothing on the internet can initiate a connection to them
```

### 3.4 Elastic IPs

| EIP | Attached to | Purpose |
|-----|-------------|---------|
| Nginx EIP | Nginx EC2 | Stable public IP for DNS (`*.ashmit.xyz`) |
| NAT EIP | NAT Gateway | Outbound source IP for private tier (AWS-managed) |

**Rule:** humans only ever DNS-point at the **Nginx EIP**.

### 3.5 VPC endpoints (admin & AWS APIs)

| Endpoint | Why |
|----------|-----|
| `ssm`, `ssmmessages`, `ec2messages` | Session Manager works without sending SSM traffic over the public internet path awkwardly |
| S3 **gateway** endpoint | Cheaper/private path for S3-backed AWS usage |

Optional ECR/logs interface endpoints exist in tfvars but are **off** for cost.

### 3.6 Security groups (the firewall story)

Terraform creates **five** SGs from the `security_groups` map:

| SG key | Attached to | Inbound idea |
|--------|-------------|--------------|
| `nginx` | Nginx | `22`, `80`, `443` from `0.0.0.0/0` (lab; tighten later) |
| `cluster` | master, worker-1, worker-2 | From **VPC CIDR**: SSH, 80/443, **6443** (API), **NodePort 30000–32767**, kubelet ports, **Calico** (BGP 179, IPIP proto 4, VXLAN 4789) |
| `jenkins` | Jenkins | `8080`, `50000` from VPC |
| `sonar` | Sonar | `9000` from VPC |
| `nexus` | Nexus | `8081` from VPC |

**Why Calico ports matter:** default Calico uses BGP + IPIP. If the cluster SG only allowed VXLAN UDP 4789, pod networking would break. The SG intentionally allows BGP + IPIP.

**Why NodePorts from VPC:** Nginx (and anything inside the VPC) must reach Ingress Controller NodePorts to serve in-cluster apps.

---

## 4. Layer 2 — Compute (the 7 EC2s)

Terraform `instances {}` creates exactly these nodes. Each gets tags:

- `Project = scopify-cluster`
- `Ansible = true`
- `Role = <map key>` (e.g. `master`, `jenkins`)

Ansible’s dynamic inventory **finds** them by those tags — you do not hardcode IPs in inventory files.

### 4.1 Public edge

#### `nginx` (Name: Nginx)

| Field | Value |
|-------|-------|
| Subnet | **public** |
| Public IP | yes + **Elastic IP** |
| Type | `t3.small` (smaller — it’s only a proxy) |
| SG | `nginx` |

**Why it exists:** Single front door.

**What Ansible puts on it (`site-nginx.yml`):**

- Docker
- Container `scopify-nginx` (`nginx:1.27-alpine`)
- Bind mounts:
  - Host `/opt/scopify-nginx/conf.d` → container `/etc/nginx/conf.d` (**read-only**)
  - `/etc/letsencrypt` → TLS certs
  - Certbot webroot for ACME
- Certbot + Cloudflare DNS plugin → wildcard cert `ashmit.xyz` + `*.ashmit.xyz`
- Host-based reverse proxy to private Jenkins / Sonar / Nexus IPs

**Edit config on the host at:** `/opt/scopify-nginx/conf.d/default.conf`  
(Ansible regenerates this from `default.conf.j2` when you re-run the playbook.)

### 4.2 Kubernetes nodes (private)

#### `master` (Name: Master)

| Field | Value |
|-------|-------|
| Subnet | **private** (no public IP) |
| Type | `c7i-flex.large` |
| SG | `cluster` |

**Why:** Control plane. This is the **brain** of Kubernetes.

**Runs after Ansible:**

- `kube-apiserver` on **:6443**
- `etcd`, `controller-manager`, `scheduler` (static pods)
- CoreDNS + kube-proxy
- Calico (CNI)
- Ingress-Nginx controller (often scheduled on any Ready node)
- Admin kubeconfig at `/home/ubuntu/.kube/config` (copied from `/etc/kubernetes/admin.conf`)

**You run `kubectl` against the Master** (or from Jenkins using a copied kubeconfig).

#### `worker-1` / `worker-2`

| Field | Value |
|-------|-------|
| Subnet | **private** |
| SG | `cluster` |

**Why two workers:** Capacity for pods + practice across AZs. They do **not** run etcd/API.

**Each worker runs:** kubelet + containerd + Calico node agent + whatever pods the scheduler places.

### 4.3 CI/CD tool VMs (private, temporary for Sonar/Nexus)

#### `jenkins`

| Field | Value |
|-------|-------|
| Ports (VPC) | `8080` UI, `50000` agents |
| Extra disk | 30 GB |

**Why dedicated EC2 (not in K8s yet):** Frozen architecture decision — CI stays on its own VM; apps move into the cluster.

**Ansible (`site-tools.yml` → `jenkins` role) installs:**

- Jenkins in Docker
- **Trivy** (image/vuln scanning)
- **kubectl** pinned to the same version as the cluster
- Copies Master’s `/etc/kubernetes/admin.conf` → `/opt/scopify-kube/config` and mounts it into the Jenkins container (`KUBECONFIG=/kube/config`)

So Jenkins can eventually `kubectl apply` / deploy without SSHing to Master.

**Public URL:** `https://jenkins.ashmit.xyz` → Nginx → private `:8080`

#### `sonar` / `nexus`

Still **separate EC2s** running Docker containers (`:9000` / `:8081`).

**Why temporary:** Faster lab bootstrap. Target architecture moves both **into Kubernetes with PVCs**, then destroys these EC2s.

**Public URLs:** `sonar.ashmit.xyz`, `nexus.ashmit.xyz` via Nginx.

---

## 5. Layer 3 — Ansible wiring (how config finds the machines)

### 5.1 Dynamic inventory

File: `ansible/inventories/aws_ec2.yml`

It queries AWS for running instances with:

- `tag:Project = scopify-cluster`
- `tag:Ansible = true`

Then groups by `Role`:

| Inventory group | Hosts |
|-----------------|-------|
| `nginx` / `edge` | Nginx |
| `master` | Master |
| `workers` | worker-1, worker-2 |
| `k8s` | master + workers |
| `jenkins` / `sonar` / `nexus` / `tools` | tool VMs |
| `private` | everything except Nginx |

`ansible_host` = public IP if present (Nginx), else private IP.

### 5.2 How Ansible reaches private nodes

Private nodes have **no public IP**, so SSH from your laptop cannot go direct.

Two supported paths:

1. **ProxyJump via Nginx** (default in docs):  
   `ssh -J ubuntu@<NGINX_EIP> ubuntu@<private-ip>`
2. **AWS SSM Session Manager** (no SSH key path needed once agent + IAM + endpoints are healthy)

### 5.3 Playbook order (required)

| Order | Playbook | What it does |
|------:|----------|--------------|
| 1 | `site.yml` | Build Kubernetes |
| 2 | `site-tools.yml` | Jenkins/Sonar/Nexus (+ Jenkins needs Master kubeconfig) |
| 3 | `site-nginx.yml` | Edge proxy (needs backends listening) |
| optional | `site-ssm.yml` | Prefer `ubuntu` in SSM sessions |

---

## 6. Layer 4 — Kubernetes in detail

### 6.1 Version pins (`group_vars/all.yml`)

| Component | Version | Role |
|-----------|---------|------|
| Kubernetes (kubeadm/kubelet/kubectl) | **1.35.6** | Cluster |
| Calico | **v3.32.1** | Pod networking (CNI) |
| Ingress-Nginx | **controller-v1.15.1** | In-cluster HTTP Host routing |
| Pod CIDR | **10.244.0.0/16** | Passed to `kubeadm init` |

These are pinned so apt/Helm/manifests do not silently drift.

### 6.2 `site.yml` — three plays

#### Play 1 — `common` (master + every worker)

Prepares the OS so kubeadm can succeed:

- Disable swap (kubeadm requirement)
- Load `br_netfilter` / `overlay`, enable IP forwarding
- Install **containerd** with `SystemdCgroup = true` (wrong cgroup config → CrashLoops)
- Install **kubeadm, kubelet, kubectl** and **hold** the packages
- SSM login helpers

Without this play, `kubeadm init/join` fails in ugly ways.

#### Play 2 — `master` only

Creates the control plane:

1. Pre-pull control-plane images (shortens init)
2. `kubeadm init --pod-network-cidr=10.244.0.0/16`  
   (initially skips CoreDNS/kube-proxy phases, then installs them with retries — resilience against flaky first boots)
3. Copy admin kubeconfig for user `ubuntu`
4. Wait until API answers on `:6443`
5. Apply **Calico** manifest → pods get routable IPs across nodes
6. Replace/apply **Ingress-Nginx** baremetal manifest → NodePort Service
7. Generate `kubeadm join …` for workers

**Important:** Master is also a schedulable node unless you taint it; in this lab, platform pods (CNI, Ingress) may land on master or workers.

#### Play 3 — `workers`

Each worker:

1. Reads the join command from Master’s hostvars
2. Runs `kubeadm join`
3. Becomes `Ready` once Calico is healthy

Idempotent: if `/etc/kubernetes/kubelet.conf` already exists, join is skipped.

### 6.3 How the cluster pieces talk

```
kubectl (on Master or Jenkins)
        │
        ▼
  kube-apiserver :6443  (Master)
        │
        ├── etcd (cluster state)
        ├── scheduler → picks a node
        └── kubelet on that node → containerd → starts containers

Pod A on worker-1  ←── Calico ──→  Pod B on worker-2
        (same 10.244.0.0/16 fabric)

Ingress object (Host: api.ashmit.xyz)
        │
        ▼
Ingress Controller watches it
        │
        ▼
NodePort on a cluster node
        │
        ▼
Edge Nginx (public) can proxy_pass to that NodePort
```

### 6.4 What is already *inside* Kubernetes today

| Namespace / piece | Status | Purpose |
|-------------------|--------|---------|
| Control plane static pods | Installed by kubeadm | API, etcd, controllers |
| CoreDNS / kube-proxy | Installed | Cluster DNS + service proxy |
| Calico | Installed by Ansible | CNI |
| `ingress-nginx` | Installed by Ansible | Ingress Controller |
| Your **test** app | Manual (you deployed) | Proved Ingress + Host routing works |

### 6.5 What is *not* in Kubernetes yet (planned)

| Workload | Planned home | Notes |
|----------|--------------|-------|
| Scopify API (NestJS) | Deployment + Service + Ingress `api.ashmit.xyz` | Needs Postgres + Redis + secrets |
| SonarQube | Helm + PVC | Retire Sonar EC2 |
| Nexus | Helm + PVC | Retire Nexus EC2 |
| Prometheus / Grafana | Helm | Observability hostnames |
| Argo CD | Helm | GitOps sync from Git |

There is not yet a managed `k8s/scopify/` manifests folder in this repo — that is the next product deploy step.

---

## 7. Layer 5 — Edge traffic & TLS

### 7.1 DNS

Cloudflare (zone `ashmit.xyz`) holds A records pointing at **Nginx EIP**:

- `jenkins.ashmit.xyz`
- `sonar.ashmit.xyz`
- `nexus.ashmit.xyz`
- (later) `api.ashmit.xyz`, `test-k8s.ashmit.xyz`, etc.

### 7.2 TLS

- Method: **Let’s Encrypt DNS-01** via Cloudflare API token  
  (needed because **wildcard** `*.ashmit.xyz` cannot be issued with HTTP-01 alone)
- Token lives in `ansible/group_vars/nginx_secrets.yml` (gitignored)
- Cert paths on host: `/etc/letsencrypt/live/ashmit.xyz/…`
- Mounted read-only into the Nginx container

### 7.3 Host routing (today)

Nginx inspects `Host` and proxies:

| Host | Upstream |
|------|----------|
| `jenkins.ashmit.xyz` | Jenkins private IP `:8080` |
| `sonar.ashmit.xyz` | Sonar private IP `:9000` |
| `nexus.ashmit.xyz` | Nexus private IP `:8081` |
| K8s app hosts (when added) | Ingress **NodePort** on a private K8s node IP |

Jenkins stays on EC2 forever (per frozen design). App traffic should go **Nginx → Ingress → Pod**.

---

## 8. Admin access model

| You want to… | How |
|--------------|-----|
| Open Jenkins UI | Browser → `https://jenkins.ashmit.xyz` |
| Shell on Nginx | SSH to EIP, or SSM |
| Shell on Master / Jenkins / workers | SSM `start-session`, or SSH ProxyJump via Nginx |
| Run kubectl | On Master as `ubuntu`, or inside Jenkins container with mounted kubeconfig |
| Change Nginx routes permanently | Edit Ansible template `roles/nginx/templates/default.conf.j2`, then `site-nginx.yml` |
| Change Nginx routes temporarily | Edit `/opt/scopify-nginx/conf.d/default.conf` on host + `nginx -s reload` (Ansible will overwrite later) |

---

## 9. End-to-end lifecycle (from zero)

```
1. terraform apply
   → VPC, subnets, IGW, NAT, SGs, 7 EC2s, Nginx EIP, IAM/SSM, endpoints

2. Wait until SSM shows private instances Online

3. ansible-playbook site.yml
   → containerd + kubeadm on 3 nodes
   → Master init + Calico + Ingress
   → Workers join → kubectl get nodes = Ready

4. ansible-playbook site-tools.yml
   → Jenkins/Sonar/Nexus containers
   → Jenkins gets kubectl + Master kubeconfig

5. Put Cloudflare A records → Nginx EIP
   Put Cloudflare API token in nginx_secrets.yml

6. ansible-playbook site-nginx.yml
   → Docker Nginx + wildcard cert + proxy to private tool IPs

7. (Next) Deploy Scopify API into K8s
   → Ingress for api.ashmit.xyz
   → Nginx upstream to Ingress NodePort
   → https://api.ashmit.xyz/health
```

---

## 10. One-paragraph summary

**Scopify Server** is an AWS lab in `ap-south-1`: Terraform creates a custom VPC (`10.20.0.0/16`) with public Nginx (EIP) and private Kubernetes + CI tool VMs behind NAT and SSM. Ansible then installs a kubeadm **1.35.6** cluster (Calico + Ingress-Nginx) on Master/worker EC2s, runs Jenkins/Sonar/Nexus as Docker on dedicated private VMs, and fronts everything with a Dockerized Nginx that terminates a Cloudflare-issued wildcard certificate for `*.ashmit.xyz`. Humans only hit the Nginx EIP; Kubernetes is the intended runtime for the Scopify API; Jenkins remains the CI brain with a copy of the cluster kubeconfig for future deploy stages.

---

## 11. Related reading

| File | Use when |
|------|----------|
| [`Scopify-Server-Architecture.drawio`](./Scopify-Server-Architecture.drawio) | Visual multi-page diagram |
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Frozen *target* design |
| [`../IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) | Ordered migration steps |
| [`../ansible/what-ansible-installs.md`](../ansible/what-ansible-installs.md) | Deep dive on K8s Ansible roles |
| [`../ansible/cmds.md`](../ansible/cmds.md) | Copy-paste runbook |
| [`../ansible/TERRAFORM_INTEGRATION.md`](../ansible/TERRAFORM_INTEGRATION.md) | Tags ↔ inventory mapping |
