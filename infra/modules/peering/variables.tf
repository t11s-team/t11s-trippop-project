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

variable "cloud_vpc_id" {
  description = "Cloud VPC ID."
  type        = string
}

variable "cloud_vpc_cidr" {
  description = "Cloud VPC CIDR."
  type        = string
}

variable "cloud_route_table_ids" {
  description = "Cloud route table IDs that should get route to On-Prem VPC."
  type        = map(string)
}

variable "onprem_vpc_id" {
  description = "On-Prem simulation VPC ID."
  type        = string
}

variable "onprem_vpc_cidr" {
  description = "On-Prem simulation VPC CIDR."
  type        = string
}

variable "onprem_route_table_ids" {
  description = "On-Prem route table IDs that should get route to Cloud VPC."
  type        = map(string)
}

variable "admin_security_group_id" {
  description = "Admin EC2 security group ID in On-Prem simulation VPC."
  type        = string
}

variable "db_port" {
  description = "Database port used by DB-related peering rules."
  type        = number
  default     = 3306
}
