# One-time bootstrap: the S3 bucket that stores Terraform state for envs/demo.
# Applied once (scripts: terraform/bootstrap.sh) and never destroyed by the demo jobs.
# Its own state is local on purpose: this bucket is the only thing it manages.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.70, < 6.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Project = var.project, ManagedBy = "terraform-bootstrap" } }

  dynamic "endpoints" {
    for_each = var.aws_endpoint == "" ? [] : [var.aws_endpoint]
    content {
      s3  = endpoints.value
      sts = endpoints.value
    }
  }
  s3_use_path_style           = var.aws_endpoint != ""
  skip_credentials_validation = var.aws_endpoint != ""
  skip_requesting_account_id  = var.aws_endpoint != ""
  skip_metadata_api_check     = var.aws_endpoint != ""
}

variable "aws_endpoint" {
  description = "AWS emulator URL (e.g. http://localhost:4566); empty = real AWS"
  type        = string
  default     = ""
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "ecommerce-devops"
}

data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.me.account_id}"
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" } # old state versions = infra rollback (Part 6, layer 5)
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}
