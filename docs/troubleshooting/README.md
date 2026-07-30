# Troubleshooting Guide

Operational runbook for Scopify infrastructure. Each issue follows: Problem → Symptoms → Root Cause → Diagnosis → Resolution → Lessons Learned → Future Prevention.

Placeholders mark where you should paste real logs/screenshots from incidents.

---

## Index

1. [SSM session fails / instance not Online](#1-ssm-session-fails--instance-not-online)
2. [Private EC2 cannot pull images / apt fails](#2-private-ec2-cannot-pull-images--apt-fails)
3. [Terraform apply creates EC2 before NAT ready](#3-terraform-apply-creates-ec2-before-nat-ready)
4. [kubeadm init / join fails](#4-kubeadm-init--join-fails)
5. [Calico pods not Ready / no cross-node traffic](#5-calico-pods-not-ready--no-cross-node-traffic)
6. [Ingress 404 / wrong Host](#6-ingress-404--wrong-host)
7. [Edge HTTPS works for Jenkins but not API](#7-edge-https-works-for-jenkins-but-not-api)
8. [Client IP always shows worker private IP](#8-client-ip-always-shows-worker-private-ip)
9. [PVC Pending (Postgres/Redis)](#9-pvc-pending-postgresredis)
10. [ImagePullBackOff from GHCR](#10-imagepullbackoff-from-ghcr)
11. [Jenkins cannot talk to Docker daemon](#11-jenkins-cannot-talk-to-docker-daemon)
12. [Trivy not found in Jenkins agent](#12-trivy-not-found-in-jenkins-agent)
13. [GHCR push unauthorized](#13-ghcr-push-unauthorized)
14. [Manifest push to Scopify-Server fails](#14-manifest-push-to-scopify-server-fails)
15. [Argo Sync failed on PreSync migrate Job](#15-argo-sync-failed-on-presync-migrate-job)
16. [API CrashLoop / DB connection errors](#16-api-crashloop--db-connection-errors)
17. [Sonar Quality Gate webhook timeout](#17-sonar-quality-gate-webhook-timeout)
18. [Let’s Encrypt / Certbot wildcard failure](#18-lets-encrypt--certbot-wildcard-failure)
19. [Ansible cannot reach private hosts](#19-ansible-cannot-reach-private-hosts)
20. [NodePort blocked / Nginx upstream timed out](#20-nodeport-blocked--nginx-upstream-timed-out)

---

## 1. SSM session fails / instance not Online

**Problem:** `aws ssm start-session` errors; Fleet Manager shows Connection Lost / no entry.

**Symptoms:**
- `TargetNotConnected`
- Agent not listed in `describe-instance-information`

**Root Cause:** Missing instance profile, agent not installed, no outbound path to SSM APIs, or endpoints/NAT not ready.

**Diagnosis:**
```bash
aws ssm describe-instance-information --region ap-south-1
# Check IAM profile on instance, SG egress, NAT, VPC endpoints
```

**Resolution:** Confirm `enable_ssm`, userdata/agent, `depends_on` network, wait 1–2 minutes after boot.

**Lessons Learned:** SSM readiness ≠ instance running.

**Future Prevention:** Keep SSM endpoints or NAT; healthcheck wait in runbooks.

[ Screenshot Required ] SSM console  
**TODO:** Waiting for screenshot

---

## 2. Private EC2 cannot pull images / apt fails

**Problem:** `apt update` or `docker pull` hangs/fails on private nodes.

**Symptoms:** Timeouts to Internet registries.

**Root Cause:** NAT Gateway missing/disabled; private route not associated; SG egress restricted (module default usually allow all — verify).

**Diagnosis:**
```bash
# On instance via SSM
curl -I https://ghcr.io
ip route
```

**Resolution:** `enable_nat_gateway = true`; verify private RT `0.0.0.0/0 → nat`; check NAT EIP.

**Lessons Learned:** Private without NAT is an island.

**Future Prevention:** Terraform dependency graph already waits for NAT before EC2 — still verify after manual changes.

---

## 3. Terraform apply creates EC2 before NAT ready

**Problem:** Historic race: instances boot without outbound.

**Symptoms:** First-boot cloud-init failures for snap/SSM.

**Root Cause:** Nodes depended only on subnet IDs.

**Diagnosis:** Read `DEPENDENCY_FLOW.md`; inspect graph.

**Resolution:** Root module `depends_on` for `module.nodes` includes VPC, endpoints, IAM, SGs; VPC module waits for NAT routes.

**Lessons Learned:** Implicit graph ≠ network readiness.

**Future Prevention:** Do not remove `depends_on` casually.

---

## 4. kubeadm init / join fails

**Problem:** Cluster bootstrap fails in `site.yml`.

**Symptoms:** Ansible task failures; kubelet not Ready; cgroup errors.

**Root Cause:** Swap on; wrong containerd cgroup; version skew; API not up before join.

**Diagnosis:**
```bash
kubelet --version
sudo swapon --show
systemctl status kubelet containerd
```

**Resolution:** Re-run `common` role; ensure pins in `group_vars/all.yml`; wait for API `:6443`.

**Lessons Learned:** Version pins exist because silent upgrades break Ingress/Calico.

**Future Prevention:** ASSERT kubelet version in Ansible (already noted in comments).

---

## 5. Calico pods not Ready / no cross-node traffic

**Problem:** Pods cannot communicate across workers.

**Symptoms:** `calico-node` CrashLoop; cross-node curl fails.

**Root Cause:** SG missing BGP (179) or IPIP (proto 4); VXLAN-only rule insufficient for default IPIP pool.

**Diagnosis:** Check cluster SG rules vs tfvars comments; `kubectl -n kube-system get pods -l k8s-app=calico-node`.

**Resolution:** Ensure Calico-related SG rules from `10.20.0.0/16` present; re-apply Terraform SG.

**Lessons Learned:** CNI mode dictates firewall needs.

**Future Prevention:** Keep tfvars comments; add connectivity test to smoke suite.

---

## 6. Ingress 404 / wrong Host

**Problem:** Hitting NodePort or edge returns default backend.

**Symptoms:** 404 from ingress-nginx.

**Root Cause:** `Host` header ≠ Ingress rule (`aws-api.ashmit.xyz` vs `api.ashmit.xyz`).

**Diagnosis:**
```bash
kubectl get ingress -A
curl -H "Host: aws-api.ashmit.xyz" http://<worker>:<nodeport>/
```

**Resolution:** Align Cloudflare DNS, Nginx `server_name`, and Ingress `host`.

**Lessons Learned:** Three places must agree on hostname.

**Future Prevention:** Single variable source (`group_vars/all.yml`) for edge hosts.

---

## 7. Edge HTTPS works for Jenkins but not API

**Problem:** Tools OK; K8s hosts time out.

**Symptoms:** 502/504 from Nginx for `aws-api` / `argocd`.

**Root Cause:** Wrong NodePort; workers down; upstream empty; Ingress controller not Ready.

**Diagnosis:**
```bash
# Compare k8s_ingress_nodeport 32522 vs actual
kubectl -n ingress-nginx get svc
```

**Resolution:** Fix NodePort in Ansible vars; re-run `site-nginx.yml`; ensure workers in upstream.

**Lessons Learned:** Edge and Ingress NodePort drift silently.

---

## 8. Client IP always shows worker private IP

**Problem:** App logs show `10.20.x.x` instead of public client IP.

**Root Cause:** Forwarded headers not trusted by Ingress.

**Diagnosis:** Check ConfigMap `ingress-nginx-controller` for `use-forwarded-headers` / `proxy-real-ip-cidr`.

**Resolution:** Apply `k8s/platform/ingress-nginx/configmap-forwarded-headers.yml` patch; restart controller.

**Lessons Learned:** Double proxy requires explicit trust CIDR.

---

## 9. PVC Pending (Postgres/Redis)

**Problem:** Volumes never bind.

**Symptoms:** `Pending` PVC; Events mention CSI/timeout.

**Root Cause:** EBS CSI not installed; IAM missing `AmazonEBSCSIDriverPolicy`; wrong StorageClass; AZ mismatch (`WaitForFirstConsumer` helps).

**Diagnosis:**
```bash
kubectl get sc,pvc -A
kubectl -n kube-system get pods | findstr ebs
```

**Resolution:** Terraform `enable_ebs_csi`; Ansible storage tasks; see `k8s/platform/storage/README.md` recovery delete/recreate.

**Lessons Learned:** CSI needs both Helm install and IAM.

---

## 10. ImagePullBackOff from GHCR

**Problem:** API/migrate pods cannot pull.

**Symptoms:** `ImagePullBackOff`; unauthorized.

**Root Cause:** Private package without `ghcr-secret`; typo in image tag; tag not pushed.

**Diagnosis:**
```bash
kubectl describe pod -n scopify-prod -l app=scopify-api
```

**Resolution:** Create docker-registry secret; uncomment/ensure `imagePullSecrets`; verify GHCR tag.

---

## 11. Jenkins cannot talk to Docker daemon

**Problem:** Check Docker stage fails.

**Symptoms:** Cannot connect to `/var/run/docker.sock`.

**Root Cause:** Socket not mounted or group permissions.

**Diagnosis:** `docker info` inside Jenkins container.

**Resolution:** Re-run `site-tools.yml` jenkins role; ensure `--group-add docker` pattern used by Ansible.

**TODO:** Waiting for log paste

---

## 12. Trivy not found in Jenkins agent

**Problem:** Trivy stage fails command not found.

**Root Cause:** Host install not bind-mounted into container.

**Resolution:** Re-run site-tools with trivy role; `docker exec jenkins trivy --version`.

---

## 13. GHCR push unauthorized

**Problem:** Login/Push stage fails.

**Root Cause:** Token lacks `packages:write`; wrong username; expired PAT.

**Resolution:** Refresh `github-token`; ensure package exists/permissions for PAT owner.

---

## 14. Manifest push to Scopify-Server fails

**Problem:** Git push rejected or auth fail.

**Root Cause:** Token lacks repo write; branch protection; nothing to commit treated as success (OK).

**Resolution:** Fix PAT scopes; check branch rules on Server `main`.

---

## 15. Argo Sync failed on PreSync migrate Job

**Problem:** Application stuck Degraded/Sync failed.

**Symptoms:** migrate Job CrashLoop; hook failed.

**Root Cause:** Bad `DATABASE_URL`; Postgres not Ready; image pull fail; migrate error.

**Diagnosis:**
```bash
kubectl -n scopify-prod logs job/scopify-migrate
kubectl -n scopify-prod get pods -l app=postgres
```

**Resolution:** Fix secrets; wait for Postgres; inspect Prisma errors; re-sync.

**Lessons Learned:** PreSync correctly blocks bad schema deploys.

**Future Prevention:** Smoke-test migrate against staging DB.

**TODO:** Waiting for Job log screenshot

---

## 16. API CrashLoop / DB connection errors

**Problem:** API pods restart.

**Symptoms:** Prisma connection errors; Redis connection errors; missing JWT_SECRET.

**Root Cause:** Secret mismatch; wrong service DNS; migrate not applied.

**Diagnosis:** `kubectl logs deploy/scopify-api -n scopify-prod`; env from secret.

**Resolution:** Align secret keys with app `.env.example`; ensure Services named as in manifests.

---

## 17. Sonar Quality Gate webhook timeout

**Problem:** QG stage hangs (when re-enabled).

**Root Cause:** Webhook to `https://jenkins.ashmit.xyz` blocked/dropped by Cloudflare; Jenkinsfile documents this.

**Resolution:** Sonar webhook → `http://<jenkins-private-ip>:8080/sonarqube-webhook/`; verify Recent deliveries 200; fallback API poll path already coded.

---

## 18. Let’s Encrypt / Certbot wildcard failure

**Problem:** HTTPS not ready; `nginx_tls_ready` false path.

**Root Cause:** Cloudflare token invalid/scope; DNS propagation; rate limits.

**Diagnosis:** Certbot logs on Nginx host; `/etc/letsencrypt/live/ashmit.xyz/`.

**Resolution:** Fix `nginx_secrets.yml`; re-run `site-nginx.yml`.

**TODO:** Waiting for log

---

## 19. Ansible cannot reach private hosts

**Problem:** SSH unreachable.

**Root Cause:** No public IP; inventory wrong; ProxyJump/SSM not configured.

**Resolution:** Use dynamic inventory + ProxyJump via Nginx EIP or SSM connection plugin per `cmds.md`.

---

## 20. NodePort blocked / Nginx upstream timed out

**Problem:** Edge → K8s times out.

**Root Cause:** Cluster SG missing `30000–32767` from VPC; wrong worker IP; CNI issue.

**Diagnosis:** From Nginx host `curl -v http://<worker-ip>:32522`; check SG.

**Resolution:** Fix SG; refresh Nginx upstream inventory; verify Ingress controller Service NodePort.

---

## Log / Screenshot Bank

| Incident date | Issue # | Link / path |
|---------------|---------|-------------|
| TODO | TODO | Waiting for project details |

Paste console logs below when available:

```
TODO:
Waiting for project details or screenshot.
```
