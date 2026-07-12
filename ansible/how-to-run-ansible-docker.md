# How to run Ansible using the Docker container

Location: `project/ansible/`

Use this guide **after** Terraform has created the Master and worker EC2 instances. Ansible configures Docker + Kubernetes on those nodes via a Docker container (`custom-ansible:latest`).

Run everything from **Ubuntu WSL** (`wsl -d Ubuntu`). Do **not** use PowerShell syntax inside WSL.

---

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| Terraform applied | Master + workers running in AWS |
| Docker Desktop | Running, with WSL integration enabled |
| Image `custom-ansible:latest` | Built from `ansible/dockerfile` at repo root |
| SSH key | EC2 key pair PEM (e.g. `terraform-aws-key.pem`) |
| AWS credentials | So dynamic inventory can list EC2 instances |

---

## Flow overview

```
WSL terminal
  → start ssh-agent + load PEM
  → docker run custom-ansible (mount repo + AWS + SSH agent)
  → inside container: ansible-inventory / ping / ansible-playbook site.yml
```

`site.yml` does three plays:

1. **common** — all nodes (Docker, kubeadm packages, sysctl, swap off)
2. **master** — `kubeadm init`, kubeconfig, Calico, ingress
3. **workers** — `kubeadm join`

---

## Step 1 — Open WSL and load the SSH key

Every **new** WSL terminal session:

```bash
wsl -d Ubuntu

eval "$(ssh-agent -s)"
ssh-add ~/.ssh/terraform-aws-key.pem
ssh-add -l
```

Expected: your key fingerprint listed.

### First time only — copy key into WSL

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp /mnt/c/Users/ashwi/.ssh/terraform-aws-key.pem ~/.ssh/
chmod 600 ~/.ssh/terraform-aws-key.pem
ssh-add ~/.ssh/terraform-aws-key.pem
```

### First time only — copy AWS credentials into WSL

```bash
mkdir -p ~/.aws
cp -r /mnt/c/Users/ashwi/.aws/* ~/.aws/
```

---

## Step 2 — Start the Ansible Docker container

From the **repository root** (not PowerShell — use WSL):

```bash
cd "/mnt/d/ashmit_personal_project/Dev Ops Project/Gaming Board Deployment"

docker run -it --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -w /workspace/project/ansible \
  custom-ansible:latest \
  sh -c "cp /workspace/project/ansible/ansible.cfg /root/ansible.cfg && chmod 600 /root/ansible.cfg && export ANSIBLE_CONFIG=/root/ansible.cfg && export ANSIBLE_INVENTORY=/workspace/project/ansible/inventories/aws_ec2.yml && exec bash"
```

### What each mount does

| Mount / flag | Purpose |
|--------------|---------|
| `-v "$(pwd):/workspace"` | Repo code (playbooks, roles, inventory) |
| `-v "$HOME/.aws:/root/.aws:ro"` | AWS credentials for `aws_ec2` inventory |
| `-v "$SSH_AUTH_SOCK:/ssh-agent"` | SSH agent so Ansible can reach EC2 |
| `-e SSH_AUTH_SOCK=/ssh-agent` | Point SSH client at the mounted agent |
| `-w /workspace/project/ansible` | Working directory for playbooks |

### Why copy `ansible.cfg` to `/root/`?

WSL/Windows bind mounts are world-writable. Ansible **ignores** `ansible.cfg` on world-writable paths. Copying it to `/root/ansible.cfg` and setting `ANSIBLE_CONFIG` fixes inventory loading.

---

## Step 3 — Inside the container: verify, then run

```bash
# 1) Confirm inventory sees Master + workers
ansible-inventory --graph

# 2) Test SSH connectivity
ansible master -m ping
ansible workers -m ping

# 3) Full K8s setup (common → master → workers)
ansible-playbook site.yml
```

Expected inventory groups: `@master`, `@workers` (and hosts like `Master`, `worker-1`, `worker-2`).

### Run only part of the playbook

```bash
# Master only (init + CNI + ingress)
ansible-playbook site.yml --limit master

# Workers only (join cluster — run after master succeeds)
ansible-playbook site.yml --limit workers
```

---

## One-liner (no interactive shell)

From repo root in WSL, after Step 1 (ssh-agent + key loaded):

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -w /workspace/project/ansible \
  custom-ansible:latest \
  sh -c "cp /workspace/project/ansible/ansible.cfg /root/ansible.cfg && chmod 600 /root/ansible.cfg && export ANSIBLE_CONFIG=/root/ansible.cfg && export ANSIBLE_INVENTORY=/workspace/project/ansible/inventories/aws_ec2.yml && ansible-playbook site.yml"
```

---

## PowerShell fallback (no SSH agent)

If you must run from PowerShell and the PEM lives under the repo (e.g. `keys/aws-keys/terraform-key.pem`):

```powershell
docker run --rm `
  -v "${PWD}:/workspace" `
  -v "$HOME/.aws:/root/.aws:ro" `
  -w /workspace/project/ansible `
  custom-ansible:latest `
  sh -c "cp /workspace/project/ansible/ansible.cfg /root/ansible.cfg && chmod 600 /root/ansible.cfg && export ANSIBLE_CONFIG=/root/ansible.cfg && export ANSIBLE_INVENTORY=/workspace/project/ansible/inventories/aws_ec2.yml && cp /workspace/keys/aws-keys/terraform-key.pem /tmp/terraform-key.pem && chmod 600 /tmp/terraform-key.pem && export ANSIBLE_PRIVATE_KEY_FILE=/tmp/terraform-key.pem && ansible-playbook site.yml"
```

Prefer the WSL + ssh-agent flow when possible.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|--------|-----|
| `Could not open a connection to your authentication agent` | No agent in WSL | Step 1 — `eval "$(ssh-agent -s)"` then `ssh-add` |
| PowerShell `ssh-add -l` works, WSL does not | Separate agents | Always load the key in **WSL**, not PowerShell |
| Empty inventory / no hosts | `ansible.cfg` ignored, or AWS creds missing | Use Step 2 config copy; check `~/.aws` mounted |
| `Permission denied (publickey)` | Agent not in container, or wrong key | Remount `$SSH_AUTH_SOCK`; confirm key matches Terraform `key_pair_name` |
| Inventory empty right after Terraform | Instances still starting / tags lag | Wait 1–2 minutes, re-run `ansible-inventory --graph` |
| Image not found | `custom-ansible:latest` not built | Build from repo `ansible/dockerfile` |

---

## Related files

| File | Purpose |
|------|---------|
| `site.yml` | Main playbook |
| `inventories/aws_ec2.yml` | Dynamic EC2 inventory |
| `ansible.cfg` | Defaults (inventory path, SSH) |
| `docker-shell.sh` | Helper to copy config inside container |
| `cmds.md` | Short command cheat sheet |
| `../terraform/cmds.md` | Create / destroy EC2 first |


use this cmds to apply the ansible to all the 6 ec2 (2 worker , 1 master , 1 jenkins , 1 sonar , 1 nexus)

ansible-playbook site.yml          # K8s
ansible-playbook site-tools.yml  

