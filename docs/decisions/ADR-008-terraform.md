# ADR-008: Terraform for AWS foundation

- **Status:** Accepted  
- **Evidence:** `Scopify Server/terraform/**`

## Context

VPC, EC2, SG, IAM, EIP, endpoints must be reproducible after destroy and reviewable as code.

## Decision

Use **Terraform** (AWS provider ~> 6) with small local modules (`vpc`, `ec2`, `security-group`, `iam-ssm`, `vpc-endpoints`). Ansible remains responsible for in-guest software.

## Alternatives

| Option | Notes |
|--------|-------|
| CloudFormation / CDK | Valid; team preference toward Terraform HCL |
| Pulumi | Similar; different language preference |
| ClickOps only | Rejected — not durable documentation |

## Tradeoffs

- **+** Explicit dependency control; plan/apply discipline  
- **−** Local state today is a risk  
- **−** Two-tool split (Terraform + Ansible) requires clear boundaries  

## Consequences

ADR and docs must state “Terraform builds the building; Ansible fits it out.” Remote state is a tracked gap (`AWS_GAPS.md`).
