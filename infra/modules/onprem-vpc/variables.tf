variable "name_prefix" {
  description = "Prefix used for Name tags. Example: t11s-dev."
  type        = string
}

variable "common_tags" {
  description = "Common tags inherited from env."
  type        = map(string)
}

variable "owner" {
  description = "Owner tag value for resources created by this module."
  type        = string
}

variable "region" {
  description = "AWS region. Used to compose VPC Endpoint service names."
  type        = string
  default     = "ap-northeast-2"
}

variable "enable_db_vpc_endpoints" {
  description = "Create SSM/SecretsManager interface endpoints + S3 gateway endpoint so the private DB EC2 reaches AWS APIs without a NAT Gateway."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for On-Prem simulation VPC."
  type        = string
}

variable "public_subnets" {
  description = "On-Prem public subnet definitions keyed by short AZ name."
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_db_subnets" {
  description = "On-Prem private DB subnet definitions keyed by short AZ name."
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {}
}
