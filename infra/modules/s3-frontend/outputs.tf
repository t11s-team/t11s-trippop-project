output "bucket_name" {
  description = "Frontend bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Frontend bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Used by CI/CD for cache invalidation."
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (*.cloudfront.net) serving the frontend."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route53 alias (A/AAAA) records pointing a custom domain at the distribution."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}
