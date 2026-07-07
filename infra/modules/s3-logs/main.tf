# TODO(성지수): implement the S3 logs module.
# Apply owner is 이성호; backup reviewer is not assigned in the current ownership table.
# Required decisions: bucket name, retention/lifecycle, encryption, access logging targets, and CloudFront/ALB log delivery policy.
locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

# S3 버킷 이름은 AWS 전역에서 유일해야 하므로 random_id 사용
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name_prefix}-s3-logs-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-s3-logs"
  })
}

# 퍼블릭 접근 차단
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 서버측 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 로그 보관 정책 (90일 후 삭제)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}
