output "bucket_name" {
  description = "The name of the created backup S3 bucket"
  value       = aws_s3_bucket.db_backup.bucket
}

output "bucket_arn" {
  description = "The ARN of the backup S3 bucket"
  value       = aws_s3_bucket.db_backup.arn
}