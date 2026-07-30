# ADR-004: Nginx EC2 as the sole public edge

- **Status:** Accepted  
- **Evidence:** ARCHITECTURE.md design locks; `nginx` instance + EIP; Ansible nginx role

## Context

Multiple tools and future apps need HTTPS hostnames. Exposing each EC2 publicly multiplies attack surface and DNS records.

## Decision

**One** public Elastic IP on an Nginx reverse proxy EC2. All `*.ashmit.xyz` records point at that EIP. Nginx terminates TLS (wildcard Let’s Encrypt DNS-01) and routes by `Host` to private tools or Ingress NodePort.

## Alternatives

| Option | Notes |
|--------|-------|
| ALB + target groups | AWS-native; Phase 3; cost + learning later |
| Cloudflare → origin per service | Still need origins; loses single AWS entry lesson |
| API Gateway | Wrong fit for Jenkins/Sonar UIs |

## Tradeoffs

- **+** Single ingress SG; cheap; excellent learning  
- **+** Works for non-K8s tools and K8s alike  
- **−** Nginx is SPOF  
- **−** Operator owns Certbot renewals / config  

## Consequences

DNS and TLS operations center on Nginx. High availability requires redesign (ALB/NHA).
