# Terraform layouts in this repo

| Path | Purpose |
|------|---------|
| **`terraform/`** | **Active** — default VPC, cluster SG, Master + worker EC2 nodes |
| `terraform/01-ec2-security-group/` | Learning — basic EC2 + SG |
| `terraform/02-custom-vpc/` | Custom VPC lab — bastion, SSM, Ansible integration |
| `terraform/03-remote-state/` | S3 + DynamoDB remote state bootstrap |
| `terraform/04-vpc-using-modules/` | VPC via modules |

Start with **`terraform/`** for the Scopify cluster nodes.

Ansible automation for K8s setup lives in **`ansible/`** (dynamic inventory via Terraform tags).

| Doc | Purpose |
|-----|---------|
| **`flow.md`** | Full create/destroy flow with diagrams and examples |
| **`cmds.md`** | Quick commands (init, apply, destroy) |
| **`modules.md`** | Module layout and port customization |
