# TODO(이창하): export image bucket name, ARN, and app access policy references.
output "bucket_name" {
  description = "Images bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Images bucket ARN."
  value       = aws_s3_bucket.this.arn
}
