# TODO(성지수): export logs bucket name and ARN for CloudFront, ALB, and monitoring modules.
output "bucket_name" {
  description = "Logs bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Logs bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "Logs bucket ID."
  value       = aws_s3_bucket.this.id
}
