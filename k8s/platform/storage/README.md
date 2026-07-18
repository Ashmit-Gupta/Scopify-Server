# Cluster storage — AWS EBS CSI + default gp3 StorageClass

## Preferred: Ansible (Master role)

After Terraform `enable_ebs_csi = true` (IAM):

```bash
# From ansible docker shell — see cmds.md
ansible-playbook site.yml --limit master
# or re-run full site.yml
```

This installs:

1. **Helm** (`helm_version` in `group_vars/all.yml`)
2. **aws-ebs-csi-driver** Helm chart (`ebs_csi_chart_version`)
3. **StorageClass `gp3`** (default) from `roles/master/templates/storageclass-gp3.yml.j2`

Toggle: `install_ebs_csi: false` in `group_vars/all.yml` to skip.

## Manual (if Ansible already ran without storage)

See steps below — same end state.

### 1) Terraform IAM

```bash
cd terraform
# enable_ebs_csi = true in terraform.tfvars
terraform apply
```

### 2–4) Helm + CSI + StorageClass

Handled by Ansible `roles/master/tasks/storage.yml`, or manually:

```bash
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system --set controller.replicaCount=1
kubectl apply -f k8s/platform/storage/storageclass-gp3.yml
```

### Recover stuck PVCs

```bash
kubectl -n scopify-prod delete pvc postgres-data redis-data --ignore-not-found
kubectl apply -f k8s/scopify-backend/prod/postgres/
kubectl apply -f k8s/scopify-backend/prod/redis/
kubectl get pvc -n scopify-prod
```
