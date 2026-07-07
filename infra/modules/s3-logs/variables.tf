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

variable "force_destroy" {
  description = "Allow bucket deletion even if not empty. true for dev, false for prod."
  type        = bool
  default     = true
}
