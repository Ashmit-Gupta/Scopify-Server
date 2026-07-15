# K8s + tools + Nginx — Quick Commands (custom VPC)

Location: `ansible/`  
Aligned with Terraform: **custom VPC**, Nginx public, other nodes private, SSM for admin.

Run from **Ubuntu WSL** (`wsl -d Ubuntu`). Do **not** use PowerShell syntax inside WSL.

---

## Prerequisites

1. `terraform apply` finished (custom VPC + instances Online).  
2. `terraform output nginx_eip` — save the EIP.  
3. PEM key in WSL agent (for SSH to Nginx / ProxyJump).  
4. AWS creds for dynamic inventory + SSM.  
5. Wait for SSM agent Online on private nodes:
   ```bash
   aws ssm describe-instance-information --region ap-south-1 \
     --query "InstanceInformationList[].{Id:InstanceId,Name:ComputerName,Ping:PingStatus}" \
     --output table
   ```

---

## Step 1 — SSH agent (WSL)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/terraform-aws-key.pem   # or your terraform-key PEM path
ssh-add -l
```

---

## Step 2 — Ansible Docker shell (repo root)

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

---

## Step 3 — Inside container

```bash
ansible-inventory --graph
# Expect: @nginx @master @workers @jenkins @sonar @nexus @private @edge @k8s @tools

# Edge (public) — direct SSH
ansible nginx -m ping

# Private nodes — group_vars/private.yml adds ProxyJump via nginx automatically
ansible private -m ping
ansible master -m ping
ansible tools -m ping

# Order matters
ansible-playbook site.yml          # K8s
ansible-playbook site-tools.yml    # Jenkins / Sonar / Nexus (+ Jenkins kubectl + master kubeconfig)
ansible-playbook site-nginx.yml    # Edge reverse proxy → private backends
ansible-playbook site-ssm.yml      # SSM sessions auto-switch ssm-user → ubuntu (all hosts)
```

Jenkins CD check after `site-tools.yml`:

```bash
# On Jenkins EC2 (or: docker exec from inventory)
docker exec jenkins kubectl get nodes
```

Manual ProxyJump override (if needed):

```bash
export ANSIBLE_SSH_COMMON_ARGS="-o ProxyJump=ubuntu@<NGINX_EIP>"
```

---

## SSM admin (no Ansible)

Default Session Manager user is `ssm-user`. To land as `ubuntu` (for kubeconfig / pipelines):

```bash
# From WSL (where aws works) — one-time account/region setting:
bash "/mnt/d/ashmit_personal_project/scopify/Scopify Server/scripts/configure-ssm-run-as-ubuntu.sh"

# OR: ansible-playbook site-ssm.yml   # also updates AWS prefs from localhost

# Then NEW session:
aws ssm start-session --target i-xxxx --region ap-south-1
whoami   # ubuntu

# Immediate override without changing prefs:
aws ssm start-session --target i-xxxx --region ap-south-1 \
  --document-name AWS-StartInteractiveCommand \
  --parameters command="sudo -iu ubuntu"
```

```bash
aws ssm start-session --target i-xxxx --region ap-south-1
# or: terraform output ssm_connect_hint
```

---

## DNS (after site-nginx.yml)

Point Squarespace A records for:

- `jenkins.ashmit.xyz`
- `sonar.ashmit.xyz`
- `nexus.ashmit.xyz`

→ Nginx Elastic IP (`terraform output nginx_eip`).

`site-nginx.yml` issues a **wildcard** Let's Encrypt cert for `ashmit.xyz` + `*.ashmit.xyz`
via Cloudflare DNS-01 (covers jenkins/sonar/nexus/test-k8s/…).

1. Create a Cloudflare API token (Zone → DNS → Edit for `ashmit.xyz`).
2. Copy secrets file and set the token:
   ```bash
   cp group_vars/nginx_secrets.yml.example group_vars/nginx_secrets.yml
   # edit: cloudflare_dns_api_token: "..."
   ```
3. Run:
   ```bash
   ansible-playbook site-nginx.yml
   ```
4. After success, set `nginx_ssl_force_wildcard: false` in `group_vars/nginx.yml`
   so renewals use `--keep-until-expiring`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Empty inventory | Tags `Project=scopify-cluster` + `Ansible=true`; wait for running |
| `private` ping fails | Nginx up? PEM loaded? ProxyJump host = nginx public/EIP |
| SSM not Online | IAM profile + agent user_data; NAT/endpoints; wait 2–5 min |
| Nginx upstream 502 | Run `site-tools.yml` first so Jenkins/Sonar/Nexus listen on private IPs |

See also: `TERRAFORM_INTEGRATION.md`
