# ADR-003: VPC endpoints for SSM

- **Status:** Accepted (SSM interface trio enabled)  
- **Evidence:** `enable_ssm_vpc_endpoints = true` in `terraform.tfvars`; `modules/vpc-endpoints`

## Context

Private instances must reach `ssm`, `ssmmessages`, and `ec2messages` APIs. Traffic can hairpin via NAT to public AWS endpoints or stay on PrivateLink.

## Decision

Enable **Interface VPC endpoints** for the SSM trio. Keep broader interface endpoints (ECR, logs, ec2) **off** for cost. Gateway endpoints for S3 remain optional behind flags.

## Alternatives

| Option | Notes |
|--------|-------|
| NAT only | Works; SSM traffic egresses via NAT EIP |
| Full endpoint set (ECR/logs/…) | Better for locked-down no-NAT designs; hourly cost multiplies |
| No endpoints + no NAT | Breaks SSM and package pulls |

## Tradeoffs

- **+** More reliable SSM; less dependency on NAT for admin plane  
- **−** Interface endpoint hourly cost  
- **−** Extra SG for endpoints  

## Consequences

Cost docs must treat SSM endpoints as intentional spend. Disabling them is only safe while NAT remains healthy.
