# TODO(이창하): implement the S3 images module.
# Apply owner is 이성호; backup reviewer is 성지수.
# Required decisions: bucket name, upload path, encryption, public access block, lifecycle, and app IAM permissions.
locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

# S3 버킷 명칭 유일성을 위한 랜덤 ID
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  # 실제 버킷명: t11s-dev-s3-images-xxxx
  bucket = "${var.name_prefix}-s3-images-${random_id.bucket_suffix.hex}"

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-s3-images"
  })
}

# 퍼블릭 액세스 차단 설정 (보안 기본)
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 기본 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
