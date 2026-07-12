# Trivy — what it is, why use it, how to install

## Purpose

**Trivy** (by Aqua Security) is a **security scanner** for your CI/CD pipeline.

| Scan type | Example | Finds |
|-----------|---------|--------|
| **Filesystem / repo** | `trivy fs .` | Vulnerable deps, secrets, misconfigs in code |
| **Container image** | `trivy image myapp:1.0` | CVEs in OS packages + app libraries inside the image |
| **IaC** | `trivy config .` | Bad Terraform / K8s YAML security settings |

Where it fits with your tools:

```
Code → Jenkins (build)
         ├─ Maven compile / test / package
         ├─ SonarQube  → code quality / bugs / smells
         ├─ Trivy      → vulnerabilities / secrets / image CVEs
         └─ Nexus      → store the built artifact
```

- **SonarQube** = quality (bugs, code smells, coverage)  
- **Trivy** = security (CVEs, secrets, risky configs)  
They complement each other; Trivy does not replace Sonar.

---

## Manual install (on the Jenkins EC2 — Ubuntu)

SSH to the **Jenkins** VM, then run:

```bash
sudo apt-get install -y wget apt-transport-https gnupg lsb-release

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | sudo tee -a /etc/apt/sources.list.d/trivy.list

sudo apt-get update
sudo apt-get install -y trivy

trivy --version
```

Make it available **inside** the Jenkins Docker container (so pipelines can run `trivy`):

```bash
docker cp /usr/bin/trivy jenkins:/usr/local/bin/trivy
docker exec jenkins trivy --version
```

Quick test:

```bash
trivy fs --severity HIGH,CRITICAL .
# or inside Jenkins container:
docker exec jenkins trivy --version
```

---

## Ansible (already wired)

| Piece | Role |
|-------|------|
| Install Trivy on Jenkins host | `roles/trivy` |
| Jenkins container + Trivy on PATH | `roles/jenkins` (mount / `docker cp`) |

```bash
# Full tools playbook (includes Trivy on Jenkins)
ansible-playbook site-tools.yml --limit jenkins

# Or only Trivy + Jenkins roles via the jenkins play
ansible-playbook site-tools.yml --limit jenkins --tags never  # not needed; just:
ansible-playbook site-tools.yml --limit jenkins
```

---

## Example Jenkinsfile stage (later)

```groovy
stage('Trivy Scan') {
    steps {
        sh 'trivy fs --severity HIGH,CRITICAL --exit-code 0 .'
        // later for Docker images:
        // sh 'trivy image --severity HIGH,CRITICAL myapp:${BUILD_NUMBER}'
    }
}
```

`--exit-code 0` = report only (don’t fail the build). Use `--exit-code 1` when you want the pipeline to fail on findings.
