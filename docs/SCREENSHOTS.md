# Screenshot Checklist

Capture these and drop them into the matching `[ Screenshot Required ]` placeholders under `docs/`.  
Check a box when the image is saved (suggested folder: `docs/diagrams/assets/`).

**Priority:** P0 = strongest proof for recruiters · P1 = important ops evidence · P2 = nice-to-have / only if feature exists

---

## P0 — Architecture & proof (capture first)

- [ ] **Overall architecture diagram** — export `Scopify Server/docs/Scopify-Server-Architecture.drawio` (or redraw) as PNG
- [ ] **AWS VPC resource map** — Console → VPC → Resource map (`10.20.0.0/16`)
- [ ] **Traffic flow annotated** — Cloudflare → EIP → Nginx → NodePort → Pod (can be draw.io)
- [ ] **CI/CD + GitOps flow** — Jenkins → GHCR → Git → Argo → Pods (diagram or collage)
- [ ] **End-to-end collage** — Jenkins green build + Argo Healthy + `curl` health response

---

## AWS Networking

- [ ] **VPC list** — Your VPCs showing `scopify-cluster` / `10.20.0.0/16`
- [ ] **Public subnets** — Tier=public (Nginx + NAT)
- [ ] **Private subnets** — Tier=private (K8s + tools)
- [ ] **Route tables** — Public → IGW · Private → NAT
- [ ] **NAT Gateway** — Console → NAT Gateways
- [ ] **Elastic IPs** — Nginx EIP + NAT EIP
- [ ] **VPC Endpoints** — SSM / ssmmessages / ec2messages
- [ ] **Security Groups** — inbound rules for `nginx`, `cluster`, `jenkins`, `sonar`, `nexus` (one shot or 5 shots)
- [ ] **Security boundaries summary** — SG overview / architecture security page

---

## DNS / Edge

- [ ] **Cloudflare DNS** — A records for `*.ashmit.xyz` → Nginx EIP
- [ ] **Nginx HTTPS proof** — browser or `curl -I https://jenkins.ashmit.xyz` (+ optional config snippet)
- [ ] **API HTTPS proof** — `https://aws-api.ashmit.xyz/health` (browser or curl)

---

## Terraform

- [ ] **`terraform plan` summary** — terminal output
- [ ] **`terraform apply` completed** — success summary
- [ ] **`terraform output`** — sanitized (IPs OK; no secrets)
- [ ] **`terraform graph`** — rendered PNG (`terraform graph | dot -Tpng`)
- [ ] **`terraform state list`** — optional inventory paste/screenshot

---

## Ansible (config management)

- [ ] **`ansible-inventory --graph`** — shows nginx/master/workers/jenkins/sonar/nexus groups
- [ ] **`ansible nginx -m ping`** — edge reachable
- [ ] **`ansible private -m ping`** — ProxyJump to private nodes works
- [ ] **`ansible-playbook site.yml` PLAY RECAP** — cluster bootstrap success
- [ ] **`ansible-playbook site-tools.yml` PLAY RECAP** — Jenkins/Sonar/Nexus
- [ ] **`ansible-playbook site-nginx.yml` PLAY RECAP** — edge + TLS
- [ ] **`docker exec jenkins kubectl get nodes`** — Jenkins has cluster access (optional)
- [ ] **Ansible Docker shell** — `custom-ansible:latest` session (optional context shot)

> Full command runbook: `Scopify Server/ansible/cmds.md` · Docs: `docs/ansible/README.md`

---

## IAM / Access

- [ ] **IAM role** — `scopify-cluster-ec2-ssm-role` trust + attached policies
- [ ] **SSM Fleet Manager** — instances Online
- [ ] **SSM session** — successful `start-session` (optional)

---

## Kubernetes

- [ ] **`kubectl get nodes -o wide`**
- [ ] **`kubectl get pods -A`**
- [ ] **`kubectl get svc -n scopify-prod`**
- [ ] **`kubectl get ingress -A`**
- [ ] **`kubectl get pvc -n scopify-prod`** (optional but strong)
- [ ] **`kubectl get sc`** — show default `gp3` (optional)

---

## Jenkins / CI

- [ ] **Job config** — Pipeline from SCM (repo + branches)
- [ ] **Green pipeline** — classic stage view or Blue Ocean (`main` or `dev`)
- [ ] **Build console** — Trivy + GHCR push excerpt (redact tokens)
- [ ] **Credentials page** — shows `github-token` exists (**redact secrets**)
- [ ] **Jenkins security realm** — Configure Global Security (auth method)

---

## Argo CD / GitOps

- [ ] **Applications list** — Healthy / Synced
- [ ] **Repositories** — Settings → Repositories (Scopify-Server)
- [ ] **Sync panel** — manual/auto sync settings
- [ ] **Resource tree** — includes PreSync `scopify-migrate` Job
- [ ] **Diff view** — after a Jenkins manifest bump

---

## Monitoring (only if deployed)

- [ ] **Prometheus → Status → Targets**
- [ ] **Grafana home / dashboard**
- [ ] **Alertmanager** (if configured)

> Skip this section if kube-prometheus-stack is still commented out.

---

## Cost / DR

- [ ] **Cost Explorer** — by service (EC2, NAT/EC2-Other, VPC endpoints)
- [ ] **Budgets alarm** — only if you created one
- [ ] **Backup / snapshots** — EBS snapshots or AWS Backup (only if they exist)

---

## Troubleshooting evidence (optional, after real incidents)

- [ ] **SSM failure/success** — for runbook #1
- [ ] **Migrate Job logs** — for PreSync failures
- [ ] **PVC Pending events** — if you hit storage issues
- [ ] **ImagePullBackOff describe** — if GHCR pull failed
- [ ] **Certbot / Nginx TLS logs** — if cert issues occurred

---

## Suggested filenames

```
docs/diagrams/assets/
  overall-architecture.png
  vpc-resource-map.png
  traffic-flow.png
  cicd-gitops.png
  e2e-collage.png
  vpc-list.png
  subnets-public.png
  subnets-private.png
  route-tables.png
  nat-gateway.png
  elastic-ips.png
  vpc-endpoints.png
  security-groups.png
  cloudflare-dns.png
  nginx-https.png
  api-health.png
  terraform-plan.png
  terraform-apply.png
  terraform-output.png
  terraform-graph.png
  ansible-inventory-graph.png
  ansible-ping-private.png
  ansible-site-recap.png
  ansible-site-tools-recap.png
  ansible-site-nginx-recap.png
  iam-ssm-role.png
  ssm-fleet.png
  kubectl-nodes.png
  kubectl-pods.png
  kubectl-svc.png
  kubectl-ingress.png
  jenkins-job-config.png
  jenkins-pipeline-green.png
  jenkins-console-trivy.png
  jenkins-credentials.png
  argocd-apps.png
  argocd-repos.png
  argocd-sync.png
  argocd-tree-migrate.png
  argocd-diff.png
  cost-explorer.pngsite
```

---

## Quick count

| Priority | Approx. count |
|----------|----------------|
| P0 | 5 |
| Networking + DNS/Edge | ~12 |
| Terraform | 4–5 |
| Ansible | 6–8 |
| IAM/SSM | 2–3 |
| Kubernetes | 4–6 |
| Jenkins | 5 |
| Argo CD | 5 |
| Monitoring / Cost / DR | 0–5 (conditional) |
| **Minimum strong portfolio set** | **~30–35** |
| **Full doc coverage** | **~50–60** |
