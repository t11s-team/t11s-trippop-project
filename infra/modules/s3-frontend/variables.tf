variable "name_prefix" {
  description = "Prefix used for Name tags. Example: t11s-dev."
  type        = string
}

variable "common_tags" {
  description = "Common tags inherited from env. Owner is passed separately per module."
  type        = map(string)
}

variable "owner" {
  description = "Owner tag value for resources created by this module."
  type        = string
}

variable "domain_aliases" {
  description = "Custom domain names (CNAMEs) for the CloudFront distribution. Empty for *.cloudfront.net only."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the custom domain. MUST be issued in us-east-1 (CloudFront requirement). Required when domain_aliases is set."
  type        = string
  default     = null
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID where CloudFront alias records are created. Required when domain_aliases is set."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_200 covers North America, Europe, and Asia (includes Korea)."
  type        = string
  default     = "PriceClass_200"
}

variable "default_root_object" {
  description = "Object returned for the distribution root and SPA fallback path."
  type        = string
  default     = "index.html"
}

variable "spa_fallback" {
  description = "When true, 403/404 from S3 return default_root_object with HTTP 200 for client-side routing."
  type        = bool
  default     = true
}
