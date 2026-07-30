# Disaster Recovery

## Purpose

Define recovery objectives honestly for a personal production-oriented lab: what can be rebuilt from Git, what is at risk, and what is not yet protected.

## Architecture

Recovery layers:

| Layer | Rebuild from | RPO (intent) | RTO (intent) |
|-------|--------------|--------------|--------------|
| VPC / EC2 | Terraform tfvars + modules | N/A (declarative) | Hours (apply + Ansible) |
| Node software | Ansible playbooks | N/A | Hours |
| App desired state | Scopify-Server `k8s/` | Git history | Minutes (Argo sync) |
| Container images | GHCR | Tag retention **TODO** | Minutes |
| Postgres/Redis data | EBS volumes / PVCs | **No automated backup in Terraform** | **TODO** |
| Terraform state | Local file | **Single point of loss** | Recreate carefully |

## Flow

### Full environment rebuild (known path)

1. `terraform apply` (custom VPC config)
2. Wait SSM Online
3. `ansible-playbook site.yml`
4. `ansible-playbook site-tools.yml`
5. Configure Cloudflare A records → Nginx EIP
6. `ansible-playbook site-nginx.yml`
7. Apply gitignored K8s secrets
8. Install/configure Argo CD; sync Applications
9. Verify `https://aws-api.ashmit.xyz/health`

Evidence: `docs/SERVER_STRUCTURE.md` §9 lifecycle.

### Data loss scenario

**TODO:** Waiting for project details — snapshot schedule, backup vault, or `pg_dump` cron not found in Terraform/Ansible.

## Components

Terraform, Ansible, Git, GHCR, EBS CSI volumes, operator runbooks in `ansible/cmds.md`.

## Tradeoffs

Accepting local state + no AWS Backup keeps cost/complexity low; unacceptable for multi-user production.

## Future Improvements

- S3 backend + DynamoDB lock for Terraform
- AWS Backup plan for EBS volumes attached to Postgres PVCs
- Documented restore drill quarterly
- Multi-master or EKS for control-plane DR

## Diagram

[ Screenshot Required ]

**Description:** Backup vault / snapshot list (when exists)  
**TODO:** Waiting for screenshot / confirmation backups exist
