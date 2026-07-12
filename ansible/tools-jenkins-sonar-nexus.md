# Jenkins, SonarQube & Nexus - 3 separate VMs

## Layout

| Instance | Type | Ports | Image |
|----------|------|-------|--------|
| Master, worker-1, worker-2 | `c7i-flex.large` | K8s cluster SG | (kubeadm via `site.yml`) |
| **Jenkins** | `c7i-flex.large` | **8080**, **50000** | `jenkins/jenkins:latest` |
| **Sonar** | `c7i-flex.large` | **9000** | `sonarqube:community` |
| **Nexus** | `c7i-flex.large` | **8081** | `sonatype/nexus3:latest` |

Total: **6x `c7i-flex.large`** (Free Tier eligible on accounts that show that badge for this type).

SG descriptions use ASCII only (`-`, not `—`).

---

## Apply

```bash
cd project/terraform
terraform apply
terraform output tools_urls
```

## Ansible

```bash
ansible-playbook site.yml          # K8s
ansible-playbook site-tools.yml    # Jenkins + Sonar + Nexus
```

Or per tool:

```bash
ansible-playbook site-tools.yml --limit jenkins
ansible-playbook site-tools.yml --limit sonar
ansible-playbook site-tools.yml --limit nexus
```

## URLs

```text
http://<jenkins-ip>:8080
http://<sonar-ip>:9000
http://<nexus-ip>:8081
```

Stop or `terraform destroy` when not practicing so Free Tier hours last.
