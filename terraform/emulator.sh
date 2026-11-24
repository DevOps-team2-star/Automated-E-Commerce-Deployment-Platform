#!/usr/bin/env bash
# Runs the SAME Terraform code against a local AWS emulator instead of real AWS.
#   ./terraform/emulator.sh cycle     apply -> verify -> destroy   (default)
#   ./terraform/emulator.sh apply     apply + verify, keep resources
#   ./terraform/emulator.sh destroy
# Env: AWS_EMULATOR_URL (default http://localhost:4566; Jenkins uses http://aws-emulator:4566)
#      ENABLE_RDS / ENABLE_ALB (default true; set false for LocalStack's free tier)
#
# What this proves: the modules, variables, state backend, outputs and generated Ansible files work.
# What it can't prove: emulated EC2 instances are records, not real servers, so Ansible/k3s are not
# exercised here (they are tested on the local k3d cluster and later on real AWS).
set -euo pipefail
cd "$(dirname "$0")"
ACTION=${1:-cycle}
URL=${AWS_EMULATOR_URL:-http://localhost:4566}
REGION=eu-central-1
ENABLE_RDS=${ENABLE_RDS:-true}
ENABLE_ALB=${ENABLE_ALB:-true}
KEY=${SSH_KEY:-$HOME/.ssh/ecom-demo}

# Fake credentials: a 12-digit access key selects account 000000000000 in MiniStack; LocalStack accepts anything.
export AWS_ACCESS_KEY_ID=000000000000 AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=$REGION AWS_DEFAULT_REGION=$REGION AWS_ENDPOINT_URL=$URL
export TF_VAR_aws_endpoint=$URL TF_IN_AUTOMATION=1
export TF_VAR_db_password=emulator-only-pass
export TF_VAR_admin_cidr=203.0.113.10/32
export TF_VAR_public_key_path=$KEY.pub TF_VAR_private_key_path=$KEY
export TF_VAR_enable_rds=$ENABLE_RDS TF_VAR_enable_alb=$ENABLE_ALB

echo "==> Emulator: $URL  (RDS=$ENABLE_RDS, ALB=$ENABLE_ALB)"
aws sts get-caller-identity --query Account --output text >/dev/null || { echo "Emulator not reachable at $URL (run scripts/emulator-up.sh)"; exit 1; }

mkdir -p "$(dirname "$KEY")"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C ecom-demo -f "$KEY"

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="ecommerce-devops-tfstate-${ACCOUNT}"

if [ "$ACTION" != "destroy" ]; then
  echo "==> Bootstrap state bucket in the emulator"
  ./bootstrap.sh
fi

echo "==> terraform init (S3 backend inside the emulator)"
cat > /tmp/backend-emulator.hcl <<HCL
bucket                      = "$BUCKET"
region                      = "$REGION"
endpoints                   = { s3 = "$URL", sts = "$URL" }
use_path_style              = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
HCL
terraform -chdir=envs/demo init -input=false -reconfigure -backend-config=/tmp/backend-emulator.hcl >/dev/null
echo "    state: s3://$BUCKET/demo/terraform.tfstate (emulated)"

# Emulators ship their own fake AMIs: use the first one instead of the Ubuntu lookup.
AMI=$(aws ec2 describe-images --query 'Images[0].ImageId' --output text 2>/dev/null || true)
[ -z "$AMI" ] || [ "$AMI" = "None" ] && AMI=ami-00000001
export TF_VAR_ami_id=$AMI

# -lock=false: S3-native locking needs conditional writes, which emulators may not implement.
TF="terraform -chdir=envs/demo"
VARS="-var-file=demo.tfvars"

verify() {
  echo "==> What the emulator now holds"
  echo "  VPCs (Project=ecom):     $(aws ec2 describe-vpcs --filters Name=tag:Project,Values=ecom --query 'length(Vpcs)' --output text)"
  echo "  Subnets:                 $(aws ec2 describe-subnets --filters Name=tag:Project,Values=ecom --query 'length(Subnets)' --output text)"
  echo "  EC2 instances:           $(aws ec2 describe-instances --filters Name=tag:Project,Values=ecom --query 'length(Reservations[].Instances[])' --output text)"
  img=$($TF output -raw images_bucket)
  echo "  S3 images uploaded:      $(aws s3 ls "s3://$img/images/" | wc -l) (bucket $img)"
  if [ "$ENABLE_RDS" = "true" ]; then
    echo "  RDS instances:           $(aws rds describe-db-instances --query 'length(DBInstances)' --output text)"
  fi
  if [ "$ENABLE_ALB" = "true" ]; then
    echo "  Load balancers:          $(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text)"
  fi
  echo "==> Terraform outputs"; $TF output
  echo "==> Generated for Ansible:"; sed 's/^/    /' ../ansible/inventory/aws.ini | grep -v '^ *#' | grep -v '^ *$'
}

case "$ACTION" in
  apply|cycle)
    $TF plan -input=false -lock=false $VARS -out=tfplan-emulator
    $TF apply -input=false -lock=false tfplan-emulator
    rm -f envs/demo/tfplan-emulator
    verify
    if [ "$ACTION" = "cycle" ]; then
      echo "==> Destroy"
      $TF destroy -input=false -lock=false -auto-approve $VARS
      echo "  EC2 instances left: $(aws ec2 describe-instances --filters Name=tag:Project,Values=ecom Name=instance-state-name,Values=pending,running --query 'length(Reservations[].Instances[])' --output text)"
    fi ;;
  destroy)
    $TF destroy -input=false -lock=false -auto-approve $VARS ;;
  *) echo "usage: emulator.sh [cycle|apply|destroy]"; exit 1 ;;
esac
echo "==> Done ($ACTION)"
