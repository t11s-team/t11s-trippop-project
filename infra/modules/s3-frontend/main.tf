# Frontend static hosting: private S3 origin fronted by CloudFront with OAC.
# Apply owner is 이성호; backup reviewer is 성지수.
# 프론트는 react-router 기반 SPA이므로 없는 key 요청(S3 403/404)을 index.html 200으로 폴백한다.
# 주의: 커스텀 도메인을 쓰면 ACM 인증서는 반드시 us-east-1 리전 발급본이어야 한다(CloudFront 제약).

locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })

  origin_id         = "${var.name_prefix}-s3-frontend-origin"
  use_custom_domain = length(var.domain_aliases) > 0 && var.acm_certificate_arn != null
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.name_prefix}-s3-frontend-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-s3-frontend"
  })
}

# 버킷은 완전 비공개로 유지하고, 접근은 오직 CloudFront OAC 경로로만 허용한다.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront가 S3 origin에 SigV4로 서명 접근하기 위한 OAC. 구방식 OAI 대신 사용한다.
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name_prefix}-s3-frontend-oac"
  description                       = "OAC for ${var.name_prefix} frontend S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS 관리형 캐시 정책(CachingOptimized): 정적 자산에 적합하며 gzip/brotli 압축을 활용한다.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} frontend"
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.domain_aliases

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # SPA 클라이언트 라우팅 폴백. OAC + 비공개 버킷에서 없는 key는 403으로 오므로 둘 다 처리한다.
  dynamic "custom_error_response" {
    for_each = var.spa_fallback ? toset([403, 404]) : toset([])
    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
      error_caching_min_ttl = 10
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 도메인 미지정 시 CloudFront 기본 인증서(*.cloudfront.net) 사용.
  # 도메인 지정 시 us-east-1 ACM 인증서로 SNI + 최소 TLS 1.2 적용.
  viewer_certificate {
    cloudfront_default_certificate = local.use_custom_domain ? null : true
    acm_certificate_arn            = local.use_custom_domain ? var.acm_certificate_arn : null
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_domain ? "TLSv1.2_2021" : null
  }

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-s3-frontend-cdn"
  })
}

# 커스텀 도메인을 Route 53 Alias 레코드로 CloudFront에 연결한다.
resource "aws_route53_record" "frontend_ipv4" {
  for_each = local.use_custom_domain && try(trimspace(var.route53_hosted_zone_id), "") != "" ? toset(var.domain_aliases) : toset([])

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "frontend_ipv6" {
  for_each = local.use_custom_domain && try(trimspace(var.route53_hosted_zone_id), "") != "" ? toset(var.domain_aliases) : toset([])

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# 이 배포(SourceArn)만 GetObject를 허용하는 버킷 정책. OAC 표준 패턴이다.
data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid       = "AllowCloudFrontOACRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  # 정책 적용 시점에 public access block이 먼저 자리잡도록 순서를 고정한다.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
