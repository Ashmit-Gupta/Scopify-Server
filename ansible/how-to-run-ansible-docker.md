# How to run Ansible (custom VPC)

Location: `ansible/`

**Canonical commands:** see [`cmds.md`](./cmds.md) and [`TERRAFORM_INTEGRATION.md`](./TERRAFORM_INTEGRATION.md).

## Short version

After Terraform custom VPC apply:

1. SSH agent + PEM in WSL  
2. Docker `custom-ansible` with AWS + SSH agent mounted  
3. `ansible-inventory --graph`  
4. `ansible nginx -m ping` then `ansible private -m ping` (ProxyJump via Nginx)  
5. Playbooks in order:
   - `site.yml` — K8s  
   - `site-tools.yml` — Jenkins / Sonar / Nexus  
   - `site-nginx.yml` — edge reverse proxy  

Private nodes have **no public IP**. Inventory uses private IP + `group_vars/private.yml` ProxyJump through Nginx. Admin alternative: AWS SSM Session Manager.
