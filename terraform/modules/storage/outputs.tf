output "bucket" {
  value = aws_s3_bucket.images.bucket
}

output "images_base_url" {
  value = "https://${aws_s3_bucket.images.bucket_regional_domain_name}/images"
}

output "uploaded_count" {
  value = length(aws_s3_object.images)
}
