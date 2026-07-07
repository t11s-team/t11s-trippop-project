variable "name_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
}

variable "common_tags" {
  description = "Common tags from environment"
  type        = map(string)
}

# 팀 규칙 필수 변수: Owner 추가
variable "owner" {
  description = "Owner tag value for resources created by this module"
  type        = string
}