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
}
