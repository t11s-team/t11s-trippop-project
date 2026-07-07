variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "s3_images_arn" {
  description = "ARN of the S3 bucket for images"
  type        = string
}

variable "db_backup_bucket_arn" {
  description = "ARN of the S3 bucket for database backups"
  type        = string
}

variable "db_artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for DB bootstrap SQL artifacts."
  type        = string
}

variable "db_runtime_ecr_repository_arns" {
  description = "ECR repository ARNs that DB EC2 can pull runtime images from."
  type        = list(string)
  default     = []
}

variable "s3_frontend_arn" {
  description = "ARN of the S3 bucket hosting the frontend build (CI deploy target)."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the frontend CloudFront distribution (for CI cache invalidation)."
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID allowed for CI API DNS record updates. Empty disables Route53 policy creation."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository (format: org/repo)"
  type        = string
  default     = "ahzldut/t11s-trippop-msa"
}

variable "lb_controller_policy_version" {
  description = "Pinned aws-load-balancer-controller release tag used to fetch iam_policy.json. Avoid 'main' to keep IAM deterministic."
  type        = string
  default     = "v3.4.0"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "eks_cluster_oidc_issuer_url" {
  description = "EKS 클러스터의 OIDC Issuer URL"
  type        = string
}

variable "enable_eks_oidc_provider" {
  description = "Whether to create IAM OIDC provider and IRSA roles for EKS. This must be known before apply."
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for EKS access entries."
  type        = string
}

variable "eks_cluster_admin_user_arns" {
  description = "List of IAM user ARNs to grant EKS cluster admin access via Access Entry API."
  type        = list(string)
  default     = []
}

variable "chatbot_setup_user_names" {
  description = "IAM user names allowed to configure AWS Chatbot Slack notification integration."
  type        = list(string)
  default     = []
}
