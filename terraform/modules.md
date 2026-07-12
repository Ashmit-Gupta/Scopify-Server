# Terraform modules — `project/terraform`

## Layout

```
project/terraform/
├── main.tf                 # data sources + module calls
├── variables.tf            # root variables (security_groups, instances, …)
├── locals.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars
└── modules/
    ├── security-group/     # reusable SG with dynamic ingress/egress rules
    └── ec2/                # single EC2 instance
```

## How port customization works

Each security group is a separate module call. Ports are not hard-coded in the module — you pass an `ingress_rules` list per SG key in `terraform.tfvars`.

### Pattern 1 — Different ports per SG

```hcl
security_groups = {
  cluster = {
    name = "gaming-board-cluster-sg"   # optional — keeps existing SG name on migration
    ingress_rules = [
      { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
      { from_port = 6443, to_port = 6443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    ]
  }

  admin = {
    ingress_rules = [
      { description = "SSH only", from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["203.0.113.10/32"] },
    ]
  }

  app = {
    ingress_rules = [
      { from_port = 8080, to_port = 8080, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    ]
  }
}
```

### Pattern 2 — Attach multiple SGs to one EC2

AWS combines rules from all attached SGs (union). Attach only what each node needs:

```hcl
instances = {
  master = {
    name                = "Master"
    security_group_keys = ["cluster", "admin"]
  }
  worker-1 = {
    name                = "worker-1"
    security_group_keys = ["cluster"]
  }
}
```

### Pattern 3 — Per-instance overrides

```hcl
worker-2 = {
  name                = "worker-2"
  security_group_keys = ["cluster"]
  instance_type       = "t3.large"
  root_volume_size    = 50
}
```

### Rule object fields

| Field | Required | Description |
|-------|----------|-------------|
| `from_port` | yes | Start port |
| `to_port` | yes | End port |
| `protocol` | yes | `tcp`, `udp`, `-1`, etc. |
| `description` | no | Rule label in AWS console |
| `cidr_blocks` | no | e.g. `["0.0.0.0/0"]` |
| `source_security_group_ids` | no | Allow traffic from another SG |
| `self` | no | Allow traffic from same SG |

### Egress

Omit `egress_rules` to default to allow-all outbound. Override per SG:

```hcl
monitoring = {
  ingress_rules = [ ... ]
  egress_rules = [
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
  ]
}
```

## Migration note

If you previously used flat resources (`aws_security_group.cluster`, `aws_instance.nodes`) and refactor to modules, Terraform `moved` blocks can rename state entries without destroying/recreating AWS resources. That is a **one-time** step — delete `moved.tf` after a successful apply.

Your state is currently empty, so no `moved` blocks are needed. Run `terraform init && terraform apply` normally.
