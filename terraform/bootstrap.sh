#!/usr/bin/env bash
# Creates the Terraform state bucket once (idempotent) and prints the backend settings.
# Bucket name: ecommerce-devops-tfstate-<aws account id>
set -euo pipefail
cd "$(dirname "$0")"
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-eu-central-1}}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="ecommerce-devops-tfstate-${ACCOUNT}"
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "State bucket $BUCKET already exists"
else
  echo "Creating state bucket $BUCKET"
  terraform -chdir=bootstrap init -input=false
  # Separate local state for the emulator so it never mixes with the real AWS bootstrap state
  if [ -n "${TF_VAR_aws_endpoint:-}" ]; then WS=emulator; else WS=default; fi
  terraform -chdir=bootstrap workspace select -or-create "$WS"
  terraform -chdir=bootstrap apply -input=false -auto-approve -var "region=$REGION"
fi
echo "backend: bucket=$BUCKET key=demo/terraform.tfstate region=$REGION"
