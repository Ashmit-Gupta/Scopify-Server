# Traffic Flow

## Purpose

Document every hop from a client browser to a pod or CI tool, including TLS and client-IP preservation.

## Architecture

Two upstream classes behind Nginx:

1. **Direct EC2 upstreams** — Jenkins `:8080`, Sonar `:9000`, Nexus `:8081`
2. **Kubernetes upstream** — `upstream k8s_ingress` → worker private IPs × NodePort `32522` (from `group_vars/nginx.yml`)

## Flow

### Human → Jenkins

```
Browser
  → https://jenkins.ashmit.xyz
  → Cloudflare DNS (A → Nginx EIP)
  → Nginx :443 (SNI / Host)
  → http://<jenkins-private-ip>:8080
```

### Human → Scopify API (prod)

```
Browser
  → https://aws-api.ashmit.xyz
  → Cloudflare → Nginx EIP :443
  → proxy_pass http://k8s_ingress  (workers:32522)
  → Ingress-Nginx (Host: aws-api.ashmit.xyz)
  → Service scopify-api:3000
  → Pod
```

### Client IP preservation

Edge Nginx sets `X-Real-IP` / `X-Forwarded-*` using Cloudflare’s `CF-Connecting-IP` when present (`default.conf.j2` map). Ingress-Nginx ConfigMap patch (`use-forwarded-headers`, `proxy-real-ip-cidr: 10.20.0.0/16`) trusts the VPC edge so apps do not see only NodePort SNAT addresses.

## Components

Cloudflare, Nginx EIP, Nginx container, private tool IPs, Ingress NodePort, Ingress resources, Services, Pods.

## Tradeoffs

| Choice | Why | Tradeoff |
|--------|-----|----------|
| NodePort baremetal Ingress | Fits kubeadm without cloud LB controller | Extra hop; NodePort must stay open in cluster SG |
| Edge TLS + optional CF proxy | Learn Certbot + CF | Double-proxy complexity if CF orange-cloud + Nginx both terminate |
| Host-based vhosts on one EIP | One DNS target | All hostnames share edge fate |

## Future Improvements

- cert-manager inside cluster for Ingress TLS (optional if edge always terminates)
- ALB + AWS Load Balancer Controller (ARCHITECTURE Phase 3)
- Separate NodePort vs hostNetwork evaluation for latency

## Diagram

[ Screenshot Required ]

**Description:** Packet path annotated (Cloudflare → EIP → Nginx → NodePort → Pod)  
**Purpose:** Incident response / onboarding  
**Evidence:** Matches Ansible nginx template + Ingress YAML  
**TODO:** Waiting for screenshot
