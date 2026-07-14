# Jenkins, SonarQube & Nexus — private EC2s (custom VPC)

## Layout (matches terraform.tfvars)

| Instance | Subnet | Ports (VPC-internal) | Image / role |
|----------|--------|----------------------|--------------|
| **Nginx** | public + EIP | 80/443 | Ansible `site-nginx.yml` |
| Master, worker-1, worker-2 | private | K8s | `site.yml` |
| **Jenkins** | private | **8080**, **50000** | `jenkins/jenkins:latest` |
| **Sonar** | private | **9000** | `sonarqube:community` |
| **Nexus** | private | **8081** | `sonatype/nexus3:latest` |

Public URLs go through Nginx hostnames (`jenkins.ashmit.xyz`, etc.), not raw private IPs.

## Apply

```bash
cd terraform
terraform apply
terraform output nginx_eip
terraform output ssm_connect_hint
```

## Ansible

```bash
ansible-playbook site.yml          # K8s (private)
ansible-playbook site-tools.yml    # Jenkins + Sonar + Nexus (private)
ansible-playbook site-nginx.yml    # Edge → private backends
```

Or per tool:

```bash
ansible-playbook site-tools.yml --limit jenkins
ansible-playbook site-tools.yml --limit sonar
ansible-playbook site-tools.yml --limit nexus
```

## URLs (after DNS → Nginx EIP)

```text
http://jenkins.ashmit.xyz
http://sonar.ashmit.xyz
http://nexus.ashmit.xyz
```

Until DNS: `curl -H "Host: jenkins.ashmit.xyz" http://<nginx_eip>/`

Stop or `terraform destroy` when idle to control cost.
