# Networking Architecture

## Purpose

Explain how VPC design isolates the public edge from private workloads, and how outbound/admin paths remain available without bastions.

## Architecture

Custom VPC `10.20.0.0/16` (`use_custom_vpc = true`), `vpc_az_count = 2`.

Subnet math (`modules/vpc`): `cidrsubnet(vpc_cidr, 4, i)` → **/20** blocks:

| Index | Tier | Example CIDR | Typical contents |
|------:|------|--------------|------------------|
| 0 | Public AZ-a | `10.20.0.0/20` | Nginx, NAT |
| 1 | Public AZ-b | `10.20.16.0/20` | Spare public |
| 2 | Private AZ-a | `10.20.32.0/20` | Master / tools (placement varies by instance order) |
| 3 | Private AZ-b | `10.20.48.0/20` | Remaining private instances |

Routing:

- Public RT: `0.0.0.0/0` → IGW  
- Private RTs: `0.0.0.0/0` → NAT Gateway (single NAT in public[0])

## Flow

See [Traffic Flow](./traffic-flow.md) and [networking/](../networking/README.md).

## Components

IGW, NAT + NAT EIP, Nginx EIP, security groups (`nginx`, `cluster`, `jenkins`, `sonar`, `nexus`), SSM interface VPC endpoints, optional S3 gateway endpoints (module supports; live gateway enablement depends on flags — SSM endpoints are on via `enable_ssm_vpc_endpoints`).

## Tradeoffs

- **True private + NAT** chosen over “SG-only private in public subnets” for realistic isolation; NAT is a significant monthly cost.
- **SSM endpoints** reduce reliance on public AWS API paths for Session Manager; interface endpoints add hourly cost.
- Cluster SG allows Calico **BGP + IPIP + VXLAN** from VPC CIDR — required for default Calico; wider than least-privilege ideal.

## Future Improvements

- Source tool ports from Nginx SG ID instead of entire VPC CIDR
- Restrict Nginx SSH from `0.0.0.0/0`
- Multi-NAT for AZ HA
- Custom Network ACLs only if defense-in-depth is required (default NACLs today)

## Diagram

[ Screenshot Required ]

**Description:** AWS Console → VPC → Resource map  
**Purpose:** Prove custom VPC, subnets, NAT, IGW  
**Evidence:** Confirms `10.20.0.0/16` deployment  
**TODO:** Waiting for screenshot
