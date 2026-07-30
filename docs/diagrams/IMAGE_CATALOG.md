# Image Catalog

Clean labels and descriptions for the imported Scopify infrastructure screenshots.

## Verified Images

| File | Clean label | What the image shows | Used in |
|------|-------------|----------------------|---------|
| `assets/01-1-vpc-ss.png` | VPC Overview | AWS VPC details page for `scopify-cluster-vpc`, including VPC ID, CIDR `10.20.0.0/16`, DNS settings, and tenancy metadata. | `docs/README.md`, `docs/networking/README.md` |
| `assets/04-resource-map.png` | VPC Resource Map | End-to-end VPC topology showing the custom VPC, 4 subnets, 4 route tables, Internet Gateway, and NAT Gateway. | `docs/README.md`, `docs/networking/README.md`, `docs/diagrams/README.md` |
| `assets/05-subnets.png` | Subnet Layout | Subnet inventory showing public and private `/20` CIDRs across `ap-south-1a` and `ap-south-1b`. | `docs/networking/README.md` |
| `assets/aws/aws-route-tables.png` | Route Table Inventory | Public and private route table resources for the custom VPC. | `docs/networking/README.md` |
| `assets/12-nat.png` | NAT Gateway Details | NAT Gateway record for `scopify-cluster-nat`, including public IP and subnet placement. | `docs/networking/README.md` |
| `assets/aws/aws-elastic-ip-addrs.png` | Elastic IP Inventory | Elastic IP allocation list showing both the NAT EIP and the Nginx edge EIP. | `docs/networking/README.md` |
| `assets/aws/aws-vpc-endpoints.png` | SSM VPC Endpoints | Interface endpoints for `ssm`, `ssmmessages`, and `ec2messages` in `ap-south-1`. | `docs/networking/README.md` |
| `assets/20-ssm-system-session-manager.png` | SSM Session Access | Successful `aws ssm start-session` into a private instance, confirming the SSM admin path works. | `docs/security/README.md` |
| `assets/23-sgs.png` | Security Groups Inventory | Security group list including `scopify-nginx-sg`, `scopify-cluster-sg`, `scopify-jenkins-sg`, `scopify-sonar-sg`, `scopify-nexus-sg`, and endpoint SGs. | `docs/networking/README.md`, `docs/diagrams/README.md` |
| `assets/28-sgs-for-cluster.png` | Cluster Security Group Rules | Detailed inbound rules for the cluster SG, including `6443`, NodePort range, kubelet ports, and Calico traffic. | `docs/networking/README.md`, `docs/diagrams/README.md` |
| `assets/aws/aws-iam-roles.png` | IAM Role Inventory | IAM roles list showing the `scopify-cluster-ec2-ssm-role` used for Session Manager access. | `docs/security/README.md` |
| `assets/34-cloudflare-dns.png` | Cloudflare DNS Records | Cloudflare DNS records for `argocd.ashmit.xyz`, `aws-api.ashmit.xyz`, `dev.ashmit.xyz`, `jenkins.ashmit.xyz`, `nexus.ashmit.xyz`, `sonar.ashmit.xyz`, and related entries. | `docs/networking/README.md` |
| `assets/49-jenkins.png` | Jenkins GitOps History | Jenkins UI `Changes` view showing recent backend pipeline history and GitOps-style deploy commits. | `docs/jenkins/README.md`, `docs/diagrams/README.md` |
| `assets/k8/k8s-cluster-info.png` | Kubernetes Cluster Info | `kubectl cluster-info` output confirming the control plane endpoint and CoreDNS are reachable. | `docs/kubernetes/README.md` |
| `assets/k8/k8s-get-pods-a.png` | Kubernetes Pods | `kubectl get pods -A` output showing Argo CD, ingress, Calico, EBS CSI, and Scopify workloads running. | `docs/kubernetes/README.md` |
| `assets/k8/k8s-get-ingress-a.png` | Kubernetes Ingress | `kubectl get ingress -A` output showing `argocd.ashmit.xyz`, `dev.ashmit.xyz`, and `aws-api.ashmit.xyz`. | `docs/kubernetes/README.md` |

## Imported But Not Yet Cleanly Classified

The remaining imported screenshots are present in `assets/` and indexed in `assets/index.csv`, but their source labels were noisy or ambiguous in the Notion export. They should be reviewed visually before being embedded in additional docs pages such as Kubernetes, Argo CD, Terraform, Monitoring, or Troubleshooting.

Examples:

- `assets/02-vpc-cidr.png`
- `assets/03-vpc-tags.png`
- `assets/11-igw.png`
- `assets/21-volume.png`
- `assets/29-ec2.png`
- `assets/41-k8s.png`

## Notes

- The imported source page mixed clean labels with unlabeled consecutive screenshots, which is why some filenames are still hash-like.
- `assets/index.csv` remains the raw extraction inventory.
- This catalog is the authoritative clean mapping for the verified screenshots.
