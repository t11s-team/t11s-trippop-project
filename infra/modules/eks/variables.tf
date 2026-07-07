variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}
variable "vpc_id" {
  description = "VPC ID."
  type        = string
}
variable "subnet_ids" {
  description = "List of subnet IDs."
  type        = list(string)
}
variable "owner" {
  description = "Owner tag value."
  type        = string
}
variable "common_tags" {
  description = "Common tags to apply."
  type        = map(string)
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster."
  type        = string
  default     = "1.34"
}

variable "node_role_arn" {
  type        = string
  description = "EKS Worker Node Role ARN (3 policies attached)"
}

variable "node_security_group_ids" {
  description = "Security group IDs attached to EKS worker nodes through the node launch template."
  type        = list(string)
  default     = []
}

variable "cluster_security_group_name_tag" {
  description = "Name tag value for the EKS-managed cluster security group. The AWS-generated security group name itself is immutable."
  type        = string
}

variable "authentication_mode" {
  description = "EKS cluster authentication mode. API manages access only through EKS Access Entry resources."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be one of CONFIG_MAP, API, API_AND_CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether the principal that creates the cluster receives bootstrap admin permissions. Keep true to match the existing cluster and avoid replacement."
  type        = bool
  default     = true
}

variable "bootstrap_self_managed_addons" {
  description = "Whether EKS bootstraps default self-managed networking add-ons. Keep false because Terraform manages vpc-cni, coredns, and kube-proxy as EKS managed add-ons."
  type        = bool
  default     = false
}
