# Default VPC Cluster — Terraform Commands

Location: `project/terraform/`

Full flow with diagrams and examples: **`flow.md`**

---

## Setup (create)

### Local / WSL

```bash
cd project/terraform

terraform init
terraform plan
terraform apply
```

Variable values live in `terraform.tfvars` (Mumbai / ap-south-1, AMI, key pair, SG rules, instances).

### Docker (custom-ansible image)

From repository root:

```bash
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -w /workspace/project/terraform \
  custom-ansible:latest \
  sh -c "terraform init && terraform apply"
```

---

## Useful outputs (after apply)

```bash
terraform output cluster_summary
terraform output nodes
terraform output instance_public_ips
terraform output master_public_ip
terraform output worker_public_ips
terraform output ssh_commands
terraform output security_group_ids
```

---

## Destroy

Destroy removes **all Terraform-managed resources** in this stack: EC2 nodes, EBS volumes, and security groups. It does **not** delete the default VPC or your EC2 key pair.

### Preview before destroy

Always review what will be removed:

```bash
cd project/terraform
terraform plan -destroy
```

### Destroy everything

```bash
terraform destroy
```

Type `yes` when prompted.

Non-interactive (scripts / CI):

```bash
terraform destroy -auto-approve
```

### Destroy via Docker

```bash
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -w /workspace/project/terraform \
  custom-ansible:latest \
  sh -c "terraform init && terraform destroy"
```

Auto-approve in Docker:

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws:ro" \
  -w /workspace/project/terraform \
  custom-ansible:latest \
  sh -c "terraform init && terraform destroy -auto-approve"
```

### Destroy order (automatic)

Terraform handles dependencies — you do not need to destroy manually in reverse:

1. EC2 instances (`module.nodes`)
2. Security groups (`module.security_groups`)

### Partial destroy — remove one worker

**Preferred:** edit `terraform.tfvars`, remove the instance key, then apply:

```bash
# Remove worker-2 from the instances map in terraform.tfvars, then:
terraform apply
```

**Alternative:** targeted destroy (also remove from tfvars afterward to keep state in sync):

```bash
terraform destroy -target='module.nodes["worker-2"]'
```

### Partial destroy — remove one security group

Only works when **no instance** references that SG in `security_group_keys`:

```bash
# 1. Remove SG from all instances' security_group_keys in tfvars
# 2. terraform apply          (updates instances)
# 3. Remove SG key from security_groups in tfvars
# 4. terraform apply          (destroys the SG)
```

### After destroy

| Item | Status |
|------|--------|
| EC2 instances | Deleted |
| Security groups | Deleted |
| `terraform.tfstate` | Still on disk (empty of resources) |
| Default VPC | Unchanged |
| Key pair `terraform-key` | Unchanged (not managed by this stack) |

To rebuild: `terraform apply` again with the same `terraform.tfvars`.

---

## Next step after apply

Configure Kubernetes with Ansible — see `project/ansible/cmds.md`.
