# Ansible ↔ Terraform Integration (project/)

Terraform creates EC2 instances in the **default VPC**. Ansible discovers them via AWS dynamic inventory using tags.

## Tags (set in project/terraform/main.tf)

| Tag | Example | Purpose |
|-----|---------|---------|
| `Project` | `gaming-board-cluster` | Inventory filter |
| `Ansible` | `true` | Inventory filter |
| `Role` | `master`, `worker-1`, `worker-2` | Group assignment |
| `Name` | `Master`, `worker-1`, `worker-2` | Hostname |

## Groups

| Group | Hosts | Ansible role |
|-------|-------|--------------|
| `master` | Master node | `common` + `master` |
| `workers` | worker-1, worker-2 | `common` + `workers` |

## Workflow

```powershell
# 1. Provision infrastructure
cd project/terraform
terraform apply

# 2. Build Ansible container (from repo root, once)
docker build -t custom-ansible:latest -f ansible/dockerfile .

# 3. Verify inventory
docker run --rm `
  -v "${PWD}:/workspace" `
  -v "$HOME/.aws:/root/.aws:ro" `
  -w /workspace/project/ansible `
  custom-ansible:latest `
  sh -c "cp /workspace/keys/aws-keys/terraform-key.pem /tmp/terraform-key.pem && chmod 600 /tmp/terraform-key.pem && export ANSIBLE_PRIVATE_KEY_FILE=/tmp/terraform-key.pem && ansible-inventory --graph"

# 4. Run full K8s setup playbook
docker run --rm `
  -v "${PWD}:/workspace" `
  -v "$HOME/.aws:/root/.aws:ro" `
  -w /workspace/project/ansible `
  custom-ansible:latest `
  sh -c "cp /workspace/keys/aws-keys/terraform-key.pem /tmp/terraform-key.pem && chmod 600 /tmp/terraform-key.pem && export ANSIBLE_PRIVATE_KEY_FILE=/tmp/terraform-key.pem && ansible-playbook site.yml"
```

## Run individual stages

```bash
# Steps 1–6 on all nodes only
ansible-playbook site.yml --limit 'master:workers' --tags never  # use roles via limit

ansible-playbook site.yml --limit master:workers  # stops after play 1 if you use --start-at-task or split playbooks

# Master only (steps 7–10) — after common is done
ansible-playbook site.yml --limit master --start-at-task "Initialize Kubernetes master"

# Workers join only
ansible-playbook site.yml --limit workers --start-at-task "Join worker nodes"
```

## Command mapping

| Step | Command | Role | Hosts |
|------|---------|------|-------|
| 1 | apt-get update | common | all |
| 2 | docker.io + socket chmod | common | all |
| 3 | apt deps + keyrings dir | common | all |
| 4 | K8s repo + GPG key | common | all |
| 5 | apt update | common | all |
| 6 | kubeadm/kubelet/kubectl 1.28.1 | common | all |
| 7 | kubeadm init | master | master |
| 8 | kubeconfig setup | master | master |
| 9 | Calico apply | master | master |
| 10 | NGINX ingress apply | master | master |
| — | kubeadm join | workers | workers |

## Note on project_name

If you change `project_name` in `terraform.tfvars`, update the filter in `inventories/aws_ec2.yml` to match.
