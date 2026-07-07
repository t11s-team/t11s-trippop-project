output "bucket_name" {
  description = "DB bootstrap artifact bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "DB bootstrap artifact bucket ARN."
  value       = aws_s3_bucket.this.arn
}
