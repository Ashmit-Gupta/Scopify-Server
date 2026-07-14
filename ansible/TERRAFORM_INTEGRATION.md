# Ansible ↔ Terraform Integration (Scopify Server)

Terraform creates a **custom VPC** (`use_custom_vpc = true`):

| Tier | Hosts | Access |
|------|-------|--------|
| Public | `nginx` (+ EIP) | SSH from laptop / DNS edge |
| Private | `master`, `worker-*`, `jenkins`, `sonar`, `nexus` | SSM or ProxyJump via Nginx |

Ansible discovers hosts via AWS dynamic inventory using tags.

## Tags (set in terraform `modules/ec2` / root)

| Tag | Example | Purpose |
|-----|---------|---------|
| `Project` | `scopify-cluster` | Inventory filter |
| `Ansible` | `true` | Inventory filter |
| `Role` | `nginx`, `master`, `worker-1`, `jenkins`, … | Group assignment |
| `Name` | `Nginx`, `Master`, … | Hostname |

## Inventory groups

| Group | Hosts | Playbooks / roles |
|-------|-------|-------------------|
| `nginx` / `edge` | Nginx | `site-nginx.yml` → `nginx` |
| `master` | Master | `site.yml` → `common` + `master` |
| `workers` | worker-1, worker-2 | `site.yml` → `common` + `workers` |
| `k8s` | master + workers | convenience group |
| `jenkins` | Jenkins | `site-tools.yml` |
| `sonar` | Sonar | `site-tools.yml` |
| `nexus` | Nexus | `site-tools.yml` |
| `tools` | jenkins+sonar+nexus | packages + docker |
| `private` | all except nginx | SSM / ProxyJump notes |

Inventory file: `inventories/aws_ec2.yml`  
`ansible_host` = public IP when present (nginx), else private IP.

## Recommended run order (after terraform apply)

```bash
# 1) Wait until SSM shows instances Online (private nodes)
aws ssm describe-instance-information --region ap-south-1 \
  --filters Key=tag:Project,Values=scopify-cluster

# 2) Inventory
ansible-inventory --graph

# 3) Ping edge (public SSH)
ansible nginx -m ping

# 4) Reach private nodes via ProxyJump (Nginx EIP from terraform output nginx_eip)
export NGINX_EIP=$(cd ../terraform && terraform output -raw nginx_eip)
export ANSIBLE_SSH_COMMON_ARGS="-o ProxyJump=ubuntu@${NGINX_EIP}"
ansible private -m ping

# 5) K8s
ansible-playbook site.yml

# 6) Jenkins / Sonar / Nexus containers
ansible-playbook site-tools.yml

# 7) Nginx → private backends
ansible-playbook site-nginx.yml
```

## SSM (optional instead of ProxyJump)

```bash
aws ssm start-session --target i-xxxx --region ap-south-1
```

For Ansible over SSM, uncomment settings in `group_vars/private.yml` (needs Session Manager plugin + usually an S3 bucket).

## Note on project_name

If you change `project_name` in `terraform.tfvars`, update the filter in `inventories/aws_ec2.yml` to match.
