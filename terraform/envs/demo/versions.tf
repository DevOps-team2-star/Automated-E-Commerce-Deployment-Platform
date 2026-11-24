terraform {
  required_version = ">= 1.10"
  required_providers {
    aws    = { source = "hashicorp/aws", version = ">= 5.70, < 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }

  # Partial backend config: bucket/region come from `terraform init -backend-config=...`
  # (bucket = ecommerce-devops-tfstate-<account id>, created by terraform/bootstrap.sh).
  backend "s3" {
    key          = "demo/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native state locking, no DynamoDB table needed
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }

  # Local AWS emulator (MiniStack or LocalStack on :4566) when var.aws_endpoint is set.
  # Empty string = real AWS: no endpoint override and all normal checks on.
  dynamic "endpoints" {
    for_each = var.aws_endpoint == "" ? [] : [var.aws_endpoint]
    content {
      ec2   = endpoints.value
      elbv2 = endpoints.value
      iam   = endpoints.value
      rds   = endpoints.value
      s3    = endpoints.value
      sts   = endpoints.value
    }
  }
  s3_use_path_style           = var.aws_endpoint != ""
  skip_credentials_validation = var.aws_endpoint != ""
  skip_requesting_account_id  = var.aws_endpoint != ""
  skip_metadata_api_check     = var.aws_endpoint != ""
}
