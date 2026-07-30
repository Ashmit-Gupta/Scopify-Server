# Authentication Flow

## Purpose

Separate **platform admin authentication** from **application user authentication**, so operators do not confuse Jenkins/Argo logins with Scopify JWT auth.

## Architecture

### A. Platform / infrastructure auth

| Surface | Mechanism |
|---------|-----------|
| AWS API / Terraform | IAM user/role credentials (operator laptop) |
| Private EC2 shell | SSM Session Manager (instance profile) or SSH (+ optional ProxyJump via Nginx) |
| Jenkins UI | Jenkins user DB / security realm (**TODO:** document exact realm from live Jenkins) |
| Argo CD UI | Argo CD admin / configured SSO (**TODO:** waiting for live config screenshot) |
| Sonar / Nexus | Tool-native admin (**TODO:** waiting for project details) |
| Cloudflare / Certbot | API token in gitignored `nginx_secrets.yml` |

### B. Scopify application auth (NestJS)

| Endpoint | Auth |
|----------|------|
| `POST /auth/register` | Public; bcrypt password; roles `CLIENT` \| `PROVIDER` |
| `POST /auth/login` | Public; returns JWT `access_token` |
| Project APIs | JWT (`passport-jwt`), payload `{ sub, role }` |
| Invite token preview | Public token on invitation |
| Accept/reject invite | JWT + role checks |

Evidence: `Scopify Backend/PROJECT_REF.md`, `backend/src/auth/`.

## Flow

### App login

```
Client → POST /auth/login { email, password }
      → AuthService verifies bcrypt
      → JWT signed with JWT_SECRET (from K8s Secret scopify-api-env)
      → Client sends Authorization: Bearer …
```

### Operator to Master

```
Operator → aws ssm start-session --target <instance-id>
        → IAM AmazonSSMManagedInstanceCore on instance profile
        → SSM endpoints (or NAT path) → shell as configured user
```

## Components

JWT secret in gitignored K8s secret, bcrypt (10 rounds), SSM IAM role `scopify-cluster-ec2-ssm-role` pattern, Cloudflare DNS token.

## Tradeoffs

- App secrets in plain Kubernetes Secrets (base64) — fine for lab; not vault-grade.
- `/users` endpoints noted as unguarded in PROJECT_REF — **production risk** if exposed publicly.
- Jenkins/Argo auth hardening not fully documented in Git — operational TODO.

## Future Improvements

- OIDC for Argo CD / Jenkins
- ExternalSecrets from AWS Secrets Manager / SSM Parameter Store
- Disable or protect `/users` in production API
- Rotate JWT secrets with documented runbook

## Diagram

[ Screenshot Required ]

**Description:** Auth sequence (app JWT + SSM admin)  
**Purpose:** Security review artifact  
**Evidence:** Code + IAM module  
**TODO:** Waiting for screenshot / live Jenkins security realm export
