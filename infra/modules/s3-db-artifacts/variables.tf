variable "name_prefix" {
  description = "Prefix used for the S3 bucket name."
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
