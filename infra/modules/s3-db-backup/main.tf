# 팀 규칙에 따른 태그 병합 로직
locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

# 팀 규칙에 따른 전역 유일 난수 생성
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. DB 백업 전용 S3 버킷 생성
resource "aws_s3_bucket" "db_backup" {
  # 난수를 포함한 버킷 이름 조합 (예: t11s-dev-s3-db-backup-a1b2c3d4)
  bucket        = "${var.name_prefix}-s3-db-backup-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-s3-db-backup"
  })
}

# 2. 수명주기 규칙 설정 (7일 뒤 자동 파기)
resource "aws_s3_bucket_lifecycle_configuration" "db_backup_lifecycle" {
  bucket = aws_s3_bucket.db_backup.id

  rule {
    id     = "db-backup-7days-expiry"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

# 3. SRE 보안 필수 세팅: 퍼블릭 접근 전면 차단
resource "aws_s3_bucket_public_access_block" "db_backup_block" {
  bucket = aws_s3_bucket.db_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. SRE 보안 필수 세팅: 기본 서버 측 암호화 (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "db_backup_encryption" {
  bucket = aws_s3_bucket.db_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
