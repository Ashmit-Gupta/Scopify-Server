# K8s Cluster Ansible — Quick Commands

Location: `project/ansible/`

Run everything from **Ubuntu WSL** (`wsl -d Ubuntu`). Do **not** use PowerShell syntax (`${env:USERPROFILE}`) in WSL.

---

## Step 1 — Start SSH agent and load key (every new WSL terminal)

Run this **once per terminal session** before Docker:

```bash
eval "$(ssh-agent -s)"

ssh-add ~/.ssh/terraform-aws-key.pem

ssh-add -l
```

Expected: your key listed (e.g. `terraform-aws-key.pem`).

If the key is not in WSL yet (first time only):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp /mnt/c/Users/ashwi/.ssh/terraform-aws-key.pem ~/.ssh/
chmod 600 ~/.ssh/terraform-aws-key.pem
ssh-add ~/.ssh/terraform-aws-key.pem
```

If AWS creds are missing in WSL (first time only):

```bash
mkdir -p ~/.aws
cp -r /mnt/c/Users/ashwi/.aws/* ~/.aws/
```

---

## Step 2 — Start Ansible Docker container (from repo root)

```bash
wsl -d Ubuntu

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

Why the config copy? WSL bind mounts are world-writable — Ansible ignores `ansible.cfg` on `/workspace`. Copying to `/root/ansible.cfg` fixes inventory loading.

---

## Step 3 — Run Ansible inside the container

```bash
# Verify inventory
ansible-inventory --graph

# Test SSH to nodes
ansible master -m ping
ansible workers -m ping

# Full K8s setup (all plays)
ansible-playbook site.yml

# CI/CD tools VMs (Jenkins / Sonar / Nexus) — after Terraform creates them
ansible-playbook site-tools.yml
```

Expected inventory groups: `@master`, `@workers` (and `@jenkins`, `@sonar`, `@nexus`, `@tools` when those VMs exist)

### Run specific plays only

```bash
ansible-playbook site.yml --limit master
ansible-playbook site.yml --limit workers
ansible-playbook site-tools.yml --limit jenkins
ansible-playbook site-tools.yml --limit sonar
ansible-playbook site-tools.yml --limit nexus
```

Docs: `tools-jenkins-sonar-nexus.md` (ports + tools flow), `what-ansible-installs.md` (K8s installs).

---

## One-liner — playbook without interactive shell

From repo root (after Step 1):

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

## Notes

| Issue | Cause | Fix |
|-------|-------|-----|
| `Could not open a connection to your authentication agent` | No WSL agent running | Step 1 — `eval "$(ssh-agent -s)"` |
| PowerShell `ssh-add -l` works, WSL doesn't | Separate agents | Always Step 1 in **WSL**, not PowerShell |
| Empty inventory | `ansible.cfg` ignored on mount | Step 2 copies config to `/root/` |
| `Permission denied (publickey)` | Agent not mounted into Docker | Step 2 must include `-v "$SSH_AUTH_SOCK:/ssh-agent"` |

---

## PowerShell fallback (copies PEM into container — no agent)

```powershell
docker run --rm -v "${PWD}:/workspace" -v "$HOME/.aws:/root/.aws:ro" -w /workspace/project/ansible custom-ansible:latest sh -c "cp /workspace/project/ansible/ansible.cfg /root/ansible.cfg && chmod 600 /root/ansible.cfg && export ANSIBLE_CONFIG=/root/ansible.cfg && export ANSIBLE_INVENTORY=/workspace/project/ansible/inventories/aws_ec2.yml && cp /workspace/keys/aws-keys/terraform-key.pem /tmp/terraform-key.pem && chmod 600 /tmp/terraform-key.pem && export ANSIBLE_PRIVATE_KEY_FILE=/tmp/terraform-key.pem && ansible-playbook site.yml"
```
