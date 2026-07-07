variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_id" {
  description = "Cloud VPC ID where the EKS cluster runs."
  type        = string
}

variable "lb_controller_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller."
  type        = string
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to install aws-load-balancer-controller through Helm."
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller. Chart 3.4.0 maps to controller app v3.4.0."
  type        = string
  default     = "3.4.0"
}

variable "aws_load_balancer_controller_image_tag" {
  description = "Controller image tag. Keep aligned with the IAM policy version in the IAM module."
  type        = string
  default     = "v3.4.0"
}

variable "enable_metrics_server" {
  description = "Whether to install metrics-server through Helm. Required for HPA CPU/memory metrics."
  type        = bool
  default     = true
}

variable "metrics_server_chart_version" {
  description = "Helm chart version for metrics-server. Chart 3.13.1 maps to app v0.8.1."
  type        = string
  default     = "3.13.1"
}

variable "enable_vpc_cni" {
  description = "Whether to manage the Amazon VPC CNI as an EKS managed add-on."
  type        = bool
  default     = true
}

variable "vpc_cni_addon_version" {
  description = "Amazon VPC CNI add-on version compatible with EKS 1.34 in ap-northeast-2."
  type        = string
  default     = "v1.21.2-eksbuild.2"
}

variable "enable_coredns" {
  description = "Whether to manage CoreDNS as an EKS managed add-on."
  type        = bool
  default     = true
}

variable "coredns_addon_version" {
  description = "CoreDNS add-on version compatible with EKS 1.34 in ap-northeast-2."
  type        = string
  default     = "v1.12.4-eksbuild.17"
}

variable "enable_kube_proxy" {
  description = "Whether to manage kube-proxy as an EKS managed add-on."
  type        = bool
  default     = true
}

variable "kube_proxy_addon_version" {
  description = "kube-proxy add-on version compatible with EKS 1.34 in ap-northeast-2."
  type        = string
  default     = "v1.34.6-eksbuild.11"
}

variable "enable_ebs_csi_driver" {
  description = "Whether to install the Amazon EBS CSI Driver as an EKS managed add-on."
  type        = bool
  default     = true
}

variable "ebs_csi_driver_addon_version" {
  description = "Amazon EBS CSI Driver add-on version compatible with EKS 1.34 in ap-northeast-2."
  type        = string
  default     = "v1.62.0-eksbuild.1"
}

variable "ebs_csi_driver_role_arn" {
  description = "IRSA role ARN used by the EBS CSI controller service account."
  type        = string
}

variable "enable_cluster_autoscaler" {
  description = "Whether to install Cluster Autoscaler through Helm."
  type        = bool
  default     = true
}

variable "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN used by the Cluster Autoscaler service account."
  type        = string
}

variable "cluster_autoscaler_chart_version" {
  description = "Cluster Autoscaler Helm chart version. Chart 9.53.0 maps to app v1.34.2."
  type        = string
  default     = "9.53.0"
}
