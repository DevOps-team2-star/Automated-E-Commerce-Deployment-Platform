# Terraform (deliverable 7)

| Path | What |
|---|---|
| `bootstrap/` + `bootstrap.sh` | S3 state bucket `ecommerce-devops-tfstate-<account>` (versioned, encrypted, private). Applied once, never destroyed. |
| `modules/network` | VPC, 2 public + 2 private subnets (`for_each` per AZ), IGW, routes. No NAT. |
| `modules/compute` | k3s server (t3.medium) + `agent_count` agents (t3.small), Ubuntu 24.04 AMI lookup, key pair, node SG (rules as separate resources, `for_each` over `admin_ports`). |
| `modules/database` | RDS PostgreSQL 16 (db.t4g.micro), private, SG 5432 from nodes only, no final snapshot. |
| `modules/storage` | S3 images bucket (random suffix, public read on `images/*`), uploads `assets/product-images/*.svg`. |
| `modules/loadbalancer` | ALB (SG with a `dynamic` ingress block over `public_ports`), target group on NodePort 30080 with `/healthz` health check, listener :80. |
| `envs/demo` | Root module: wires the modules, `enable_rds` toggles RDS with `count`, writes the Ansible inventory and variables with `templatefile`. |

Run by hand (normally Jenkins `infra-apply` / `infra-destroy` does this):

```bash
./terraform/bootstrap.sh
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
terraform -chdir=terraform/envs/demo init -backend-config="bucket=ecommerce-devops-tfstate-$ACCOUNT" -backend-config="region=eu-central-1"
export TF_VAR_db_password='choose-a-password' TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
terraform -chdir=terraform/envs/demo plan -var-file=demo.tfvars -out=tfplan
terraform -chdir=terraform/envs/demo apply tfplan
terraform -chdir=terraform/envs/demo destroy -var-file=demo.tfvars
```

Labs (docs/PLAN.md, Part 7): `-var agent_count=2` (count), `-var enable_rds=false` (conditional module),
`terraform workspace new test` + `-var-file=test.tfvars` (workspaces), `-var agent_count=9` (validation),
`public_ports = [80, 8080]` in a tfvars file (dynamic block).
