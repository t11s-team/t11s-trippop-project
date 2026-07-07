resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name_prefix}-s3-db-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name  = "${var.name_prefix}-s3-db-artifacts"
    Owner = var.owner
  })
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
