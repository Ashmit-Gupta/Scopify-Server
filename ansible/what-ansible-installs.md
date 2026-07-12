# What Ansible installs — and how the Kubernetes cluster works

Location: `project/ansible/`

This document explains **what** `ansible-playbook site.yml` installs on Master and workers, **why** each piece is needed, and **how** the pieces work together after Terraform has created the EC2 nodes.

Related runbook: [`how-to-run-ansible-docker.md`](./how-to-run-ansible-docker.md)

---

## Big picture

```
Terraform (EC2 + SG)
        │
        ▼
Ansible site.yml
   ├─ Play 1: common   → ALL nodes (Master + workers)
   ├─ Play 2: master   → Master only (kubeadm init + CNI + ingress)
   └─ Play 3: workers  → Workers only (kubeadm join)
        │
        ▼
Kubernetes cluster (kubeadm 1.28.1 + Calico + NGINX Ingress)
```

| Role | Hosts | Job |
|------|--------|-----|
| `common` | Master + workers | OS prep, container runtime, kubeadm/kubelet/kubectl |
| `master` | Master only | Create control plane, kubeconfig, Calico, ingress |
| `workers` | Workers only | Join the cluster using Master’s join token |

Version pin (from `group_vars/all.yml`): **Kubernetes 1.28.1**, pod network CIDR **`10.244.0.0/16`**.

---

## How it works end-to-end

### 1. Inventory finds the nodes

`inventories/aws_ec2.yml` queries AWS for running instances tagged:

- `Ansible=true`
- `Project=gaming-board-cluster`
- `Role=master` → group `master`
- `Role=worker-1` or `worker-2` → group `workers`

Ansible SSHs as `ubuntu` using your SSH agent / key.

### 2. Common role prepares every node

Every node that will run pods (Master and workers) needs the same baseline:

- No swap (kubeadm requirement)
- Kernel modules + sysctl for bridging / IP forwarding
- **containerd** (actual CRI used by kubelet) with `SystemdCgroup = true`
- **kubeadm**, **kubelet**, **kubectl** at 1.28.1 (packages held so apt won’t upgrade them)

Without this, `kubeadm init` / `kubeadm join` fails (e.g. missing `br_netfilter`, or etcd/apiserver CrashLoopBackOff if containerd cgroups are wrong).

### 3. Master role creates the control plane

On Master only:

1. `kubeadm init --pod-network-cidr=10.244.0.0/16`  
   Starts static pods: **etcd**, **kube-apiserver**, **controller-manager**, **scheduler**.
2. Copies `/etc/kubernetes/admin.conf` → `/home/ubuntu/.kube/config` so `kubectl` works as `ubuntu`.
3. Applies **Calico** (pod networking / CNI).
4. Applies **NGINX Ingress** (HTTP(S) routing into the cluster).
5. Creates a **join command** (`kubeadm token create --print-join-command`) for workers.

API server listens on **`:6443`**. That is the brain of the cluster.

### 4. Workers role joins the cluster

On each worker:

1. If `/etc/kubernetes/kubelet.conf` already exists → already joined (skip).
2. Otherwise run the Master’s join command → worker kubelet registers with the API.
3. Worker becomes a node (`Ready` once CNI is healthy).

Workers do **not** run etcd/apiserver. They run **kubelet + containerd** and execute pods scheduled onto them.

### 5. Day-to-day usage

```
You ──kubectl──► Master (API :6443) ──schedules──► Worker kubelets ──run──► containers (containerd)
```

- Run `kubectl` on the **Master** (or any machine with admin kubeconfig).
- Workers usually have **no** kubeconfig → `kubectl` on a worker fails with `localhost:8080` — that is normal.

---

## Play 1 — `common` (Master + workers)

### OS / kernel prerequisites

| What | Why |
|------|-----|
| `apt update` | Fresh package indexes before installs |
| `swapoff -a` + remove swap from `/etc/fstab` | kubeadm refuses to run with swap enabled |
| Kernel modules `br_netfilter`, `overlay` | Bridge netfilter for iptables; overlay for container filesystems |
| Persist modules in `/etc/modules-load.d/k8s.conf` | Survive reboot |
| Sysctl: `bridge-nf-call-iptables`, `bridge-nf-call-ip6tables`, `ip_forward` | Pods can talk across nodes; kube-proxy / CNI can work |
| Persist sysctl in `/etc/sysctl.d/99-kubernetes.conf` | Survive reboot |

Without `br_netfilter` / those sysctls, `kubeadm init` fails preflight (`bridge-nf-call-iptables does not exist`).

### Container runtime

| What | Why |
|------|-----|
| Install **containerd** + **docker.io** | kubeadm/kubelet use **containerd** as CRI; Docker is optional helper |
| `/etc/containerd/config.toml` with **`SystemdCgroup = true`** | Matches kubelet’s cgroup driver — required or etcd/apiserver crash-loop |
| Start/enable `containerd` (and Docker) | Runtime must be up before kubelet starts pods |
| `/etc/crictl.yaml` → containerd socket | `crictl ps` / debugging without guessing sockets |

**Important:** Control-plane pods (etcd, apiserver) run via **containerd**, not `docker ps`. Use `crictl` to inspect them.

### Kubernetes packages

| Package | Role on Master | Role on worker |
|---------|----------------|----------------|
| **kubeadm** | `kubeadm init`, tokens, upgrades | `kubeadm join` (once) |
| **kubelet** | Runs control-plane static pods + node agent | Runs pods on that node |
| **kubectl** | Cluster CLI (primary place to use it) | Optional; not needed for day-to-day |

Also installed: apt HTTPS deps, Kubernetes apt repo + GPG key, then packages pinned to **1.28.1** and **held** so accidental `apt upgrade` doesn’t break the cluster.

---

## Play 2 — `master` (Master only)

| Step | What | Why |
|------|------|-----|
| Re-apply modules/sysctl | Safety before init | Same networking prerequisites as common |
| Skip init if `/etc/kubernetes/admin.conf` exists | Idempotent re-runs | Don’t wipe an existing control plane |
| `kubeadm init --pod-network-cidr=10.244.0.0/16` | Create control plane | Starts API, etcd, controller, scheduler |
| Wait for port **6443** | API must be up | Before copying kubeconfig / applying manifests |
| Copy admin kubeconfig to `ubuntu` | Non-root `kubectl` | Operator convenience |
| Apply **Calico** | CNI / pod network | Nodes stay `NotReady` without a CNI; pods need IPs in `10.244.0.0/16` |
| Apply **NGINX Ingress** | Ingress controller | Expose HTTP services (NodePort / bare-metal style) |
| `kubeadm token create --print-join-command` | Join string for workers | Workers play reads this from Master hostvars |

### Control-plane components (started by kubeadm)

| Component | Purpose |
|-----------|---------|
| **etcd** | Cluster state database |
| **kube-apiserver** | API (`kubectl`, kubelets talk here) |
| **kube-controller-manager** | Controllers (replicas, nodes, etc.) |
| **kube-scheduler** | Decides which node runs each pod |

---

## Play 3 — `workers` (workers only)

| Step | What | Why |
|------|------|-----|
| Check `/etc/kubernetes/kubelet.conf` | Already joined? | Skip join on re-run |
| Read join command from Master | From `hostvars[master].kubeadm_join_command` | Single source of truth after init |
| `kubeadm join ...` | Register with API | kubelet gets credentials; node appears in `kubectl get nodes` |

After join, Master shows workers as nodes. They keep running **kubelet + containerd** forever; you do **not** re-join unless the node was reset.

### Master init resilience (avoids CoreDNS timeout / kubectl :8080)

The master role:

1. Pre-pulls control-plane images  
2. Runs `kubeadm init` **without** CoreDNS/kube-proxy (those phases used to time out)  
3. Copies `/etc/kubernetes/admin.conf` → `/home/ubuntu/.kube/config` **before** addons  
4. Waits until `kubectl get --raw=/readyz` succeeds  
5. Installs CoreDNS + kube-proxy with retries, then Calico + ingress  
6. Verifies `kubectl get nodes` before finishing  

If `admin.conf` exists but `:6443` is down, Ansible fails with explicit `kubeadm reset` instructions (broken partial init).

---

## What runs where (cheat sheet)

```
┌──────────────────────────── MASTER ────────────────────────────┐
│  containerd + kubelet                                          │
│  etcd, kube-apiserver :6443, controller, scheduler             │
│  kubectl + ~/.kube/config                                      │
│  Calico / ingress (as pods, often on any Ready node)           │
└────────────────────────────────────────────────────────────────┘
         ▲ join / heartbeats
┌──────────────────────────── WORKERS ───────────────────────────┐
│  containerd + kubelet                                          │
│  kubeadm (used at join time)                                   │
│  NO admin kubeconfig by default (kubectl → localhost:8080)     │
│  Application pods scheduled here                               │
└────────────────────────────────────────────────────────────────┘
```

---

## Verify after Ansible

On **Master** only:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
```

Healthy = all nodes **Ready**, system pods **Running** (Calico, CoreDNS, kube-proxy, etc.).

Public IPs of workers: use Terraform (`terraform output worker_public_ips`) or Ansible inventory (`ansible_host`) — not `kubectl` EXTERNAL-IP (no cloud provider in this kubeadm setup).

---

## Why something might fail (quick map)

| Symptom | Likely cause | Related install step |
|---------|--------------|----------------------|
| `bridge-nf-call-iptables does not exist` | Module/sysctl missing | common: `br_netfilter` + sysctl |
| `:6443 connection refused` | API/etcd down | containerd `SystemdCgroup`, or control-plane CrashLoop |
| `docker ps` empty but cluster exists | Pods on containerd | Use `crictl`, not Docker |
| Worker `kubectl` → `localhost:8080` | No kubeconfig on worker | Expected — use Master |
| Nodes `NotReady` forever | CNI missing/broken | Calico apply on Master |
| Worker won’t join | No token / Master not ready | Run master play first |

---

## File map

| Path | Purpose |
|------|---------|
| `site.yml` | Orchestrates the three plays |
| `roles/common/` | Packages + OS + containerd on all nodes |
| `roles/master/` | `kubeadm init`, Calico, ingress, join token |
| `roles/workers/` | `kubeadm join` |
| `group_vars/all.yml` | Version, CIDR, Calico/ingress URLs, sysctl/modules |
| `group_vars/master.yml` | kubeconfig user/path for Master |
| `inventories/aws_ec2.yml` | Dynamic EC2 inventory by tags |

---

## One-line summary

Ansible turns Terraform EC2s into a kubeadm cluster by installing the **same runtime + kube tools on every node**, **initializing the control plane on Master**, wiring **Calico + Ingress**, then **joining workers** so the Master’s API can schedule work onto them.
