# Ansible

Configuration management for Scopify Server EC2s.  
**Terraform builds the AWS skeleton; Ansible installs and configures software on the VMs.**

| Field | Value |
|-------|-------|
| Root | `Scopify Server/ansible/` |
| Inventory | Dynamic EC2 — `inventories/aws_ec2.yml` |
| Tags required | `Project=scopify-cluster`, `Ansible=true` |
| Run environment | Docker image `custom-ansible:latest` from WSL (see `cmds.md`) |
| Operator runbook | `Scopify Server/ansible/cmds.md` |

---

## Purpose

| Concern | Owner |
|---------|-------|
| VPC, EC2, SG, EIP, IAM | Terraform |
| containerd, kubeadm, Calico, Ingress, EBS CSI | Ansible `site.yml` |
| Jenkins / Sonar / Nexus Docker | Ansible `site-tools.yml` |
| Edge Nginx + TLS | Ansible `site-nginx.yml` |
| SSM login as `ubuntu` | Ansible `site-ssm.yml` |

---

## Folder Structure

```
ansible/
├── ansible.cfg
├── inventories/aws_ec2.yml      # Dynamic inventory (AWS tags)
├── group_vars/
│   ├── all.yml                  # K8s versions, domain, hostnames
│   ├── private.yml              # ProxyJump via Nginx for private hosts
│   ├── nginx.yml / jenkins.yml / …
│   └── nginx_secrets.yml        # gitignored Cloudflare token
├── roles/
│   ├── common / master / workers
│   ├── jenkins / sonarqube / nexus / trivy / docker
│   ├── nginx / ssm_login / packages
└── site.yml | site-tools.yml | site-nginx.yml | site-ssm.yml
```

---

## Playbook Order (required)

| Order | Playbook | What it does |
|------:|----------|--------------|
| 1 | `site.yml` | OS prep → kubeadm init/join → Calico → Ingress-Nginx → Helm + EBS CSI |
| 2 | `site-tools.yml` | Jenkins / Sonar / Nexus (+ Jenkins kubectl + master kubeconfig) |
| 3 | `site-nginx.yml` | Docker Nginx edge + Certbot wildcard + Host routing |
| 4 | `site-ssm.yml` (optional) | Prefer `ubuntu` in SSM sessions |

**Why this order:** Tools need listening ports before Nginx upstreams; Jenkins needs Master kubeconfig after cluster exists.

---

## Canonical Commands

Source of truth for copy-paste: `Scopify Server/ansible/cmds.md`.  
Run from **Ubuntu WSL** — not PowerShell.

### Prerequisites

```bash
# After terraform apply — wait for SSM Online
aws ssm describe-instance-information --region ap-south-1 \
  --query "InstanceInformationList[].{Id:InstanceId,Name:ComputerName,Ping:PingStatus}" \
  --output table

terraform output nginx_eip
```

### SSH agent (WSL)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/terraform-aws-key.pem   # match your key_pair_name PEM
ssh-add -l
```

### Enter Ansible Docker shell

```bash
cd "/mnt/d/ashmit_personal_project/scopify/Scopify Server"

docker run -it --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -w /workspace/ansible \
  custom-ansible:latest \
  sh -c "cp /workspace/ansible/ansible.cfg /root/ansible.cfg && chmod 600 /root/ansible.cfg && export ANSIBLE_CONFIG=/root/ansible.cfg && export ANSIBLE_INVENTORY=/workspace/ansible/inventories/aws_ec2.yml && exec bash"
```

### Inside the container — inventory & ping

```bash
ansible-inventory --graph
# Expect groups: nginx, master, workers, jenkins, sonar, nexus, private, edge, k8s, tools

ansible nginx -m ping          # public edge — direct SSH
ansible private -m ping        # ProxyJump via Nginx (group_vars/private.yml)
ansible master -m ping
ansible tools -m ping
```

### Apply playbooks

```bash
ansible-playbook site.yml          # Kubernetes cluster
ansible-playbook site-tools.yml    # CI tool VMs
ansible-playbook site-nginx.yml    # Edge + TLS (needs Cloudflare token in nginx_secrets.yml)
ansible-playbook site-ssm.yml      # Optional SSM run-as ubuntu
```

### Storage-only re-run (existing cluster)

```bash
ansible-playbook site.yml --limit master
# then on master:
kubectl get sc
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver
```

### Jenkins kubectl check (after site-tools)

```bash
docker exec jenkins kubectl get nodes
```

### Manual ProxyJump override

```bash
export ANSIBLE_SSH_COMMON_ARGS="-o ProxyJump=ubuntu@<NGINX_EIP>"
```

### SSM admin (without Ansible SSH)

```bash
aws ssm start-session --target i-xxxx --region ap-south-1
# or: terraform output ssm_connect_hint
```

---

## Inventory Groups

| Group | Hosts |
|-------|-------|
| `nginx` / `edge` | Nginx |
| `master` | Control plane |
| `workers` | worker-1, worker-2 |
| `k8s` | master + workers |
| `jenkins` / `sonar` / `nexus` / `tools` | Tool VMs |
| `private` | Everything except Nginx |

`ansible_host` = public IP if present (Nginx), else private IP.

---

## How Ansible Reaches Private Nodes

Private EC2s have **no public IP**.

1. **SSH ProxyJump via Nginx** (default for playbooks) — PEM on agent, jump through Nginx EIP  
2. **AWS SSM Session Manager** — admin shells without SSH key path  

---

## Roles (what gets installed)

| Role | Installs / configures |
|------|------------------------|
| `common` | Swap off, sysctl, containerd, kubeadm/kubelet/kubectl holds |
| `master` | kubeadm init, Calico, Ingress-Nginx, Helm, EBS CSI, join cmd |
| `workers` | kubeadm join |
| `jenkins` | Jenkins Docker + kubectl + kubeconfig mount |
| `trivy` | Trivy on host / bind into Jenkins |
| `sonarqube` / `nexus` | Tool containers on dedicated EC2s |
| `nginx` | `scopify-nginx` container + Certbot DNS-01 |
| `ssm_login` | Prefer ubuntu for SSM |

Version pins live in `group_vars/all.yml` (Kubernetes 1.35.6, Calico v3.29.4, Ingress-Nginx controller-v1.15.1).

---

## Tradeoffs

| Decision | Why | Cost / risk |
|----------|-----|-------------|
| Ansible + Terraform split | Clear IaC vs config boundary | Two tools to learn |
| Dynamic inventory | No hardcoded IPs | Needs AWS creds + correct tags |
| Dockerized Ansible | Reproducible controller | Must mount AWS + SSH agent |
| ProxyJump | Works without SSM for playbooks | Nginx SSH must stay reachable |

---

## Future Improvements

- Ansible Vault for all secrets (not only gitignore)
- Molecule tests for roles
- CI dry-run (`ansible-playbook --check`) on PRs
- SSM connection plugin as default instead of SSH ProxyJump

---

## Screenshots

[ Screenshot Required ]

**Description:** `ansible-inventory --graph`  
**Purpose:** Prove dynamic inventory discovers all 7 roles  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** `ansible private -m ping` success  
**Purpose:** Prove ProxyJump to private tier  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** `ansible-playbook site.yml` PLAY RECAP (all ok)  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** `ansible-playbook site-tools.yml` PLAY RECAP  
**TODO:** Waiting for screenshot

[ Screenshot Required ]

**Description:** `ansible-playbook site-nginx.yml` PLAY RECAP + TLS ready  
**TODO:** Waiting for screenshot

---

## Related

- Operator cheat sheet: [`Scopify Server/ansible/cmds.md`](../../Scopify%20Server/ansible/cmds.md)
- [`TERRAFORM_INTEGRATION.md`](../../Scopify%20Server/ansible/TERRAFORM_INTEGRATION.md)
- [Terraform docs](../terraform/README.md)
- [Screenshot checklist](../SCREENSHOTS.md)
