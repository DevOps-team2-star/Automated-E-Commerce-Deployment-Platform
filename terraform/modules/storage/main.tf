# Public-read S3 bucket for product images (the storefront loads them directly from S3).
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "images" {
  bucket        = "${var.name}-images-${random_id.suffix.hex}"
  force_destroy = true # demo: destroy also deletes the uploaded objects
}

resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false # the bucket policy below makes images/* readable
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "PublicReadProductImages"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.images.arn}/images/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket     = aws_s3_bucket.images.id
  policy     = data.aws_iam_policy_document.public_read.json
  depends_on = [aws_s3_bucket_public_access_block.images] # policy is rejected until the block is relaxed
}

resource "aws_s3_object" "images" {
  for_each     = fileset(var.images_dir, "*.svg")
  bucket       = aws_s3_bucket.images.id
  key          = "images/${each.value}"
  source       = "${var.images_dir}/${each.value}"
  etag         = filemd5("${var.images_dir}/${each.value}")
  content_type = "image/svg+xml"
}
