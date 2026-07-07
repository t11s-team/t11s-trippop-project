output "aws_load_balancer_controller_release_name" {
  description = "Helm release name for aws-load-balancer-controller."
  value       = try(helm_release.aws_load_balancer_controller[0].name, null)
}

output "aws_load_balancer_controller_namespace" {
  description = "Namespace where aws-load-balancer-controller is installed."
  value       = try(helm_release.aws_load_balancer_controller[0].namespace, null)
}

output "metrics_server_release_name" {
  description = "Helm release name for metrics-server."
  value       = try(helm_release.metrics_server[0].name, null)
}

output "metrics_server_namespace" {
  description = "Namespace where metrics-server is installed."
  value       = try(helm_release.metrics_server[0].namespace, null)
}

output "ebs_csi_driver_addon_name" {
  description = "EKS managed add-on name for the Amazon EBS CSI Driver."
  value       = try(aws_eks_addon.ebs_csi_driver[0].addon_name, null)
}

output "vpc_cni_addon_name" {
  description = "EKS managed add-on name for the Amazon VPC CNI."
  value       = try(aws_eks_addon.vpc_cni[0].addon_name, null)
}

output "coredns_addon_name" {
  description = "EKS managed add-on name for CoreDNS."
  value       = try(aws_eks_addon.coredns[0].addon_name, null)
}

output "kube_proxy_addon_name" {
  description = "EKS managed add-on name for kube-proxy."
  value       = try(aws_eks_addon.kube_proxy[0].addon_name, null)
}

output "cluster_autoscaler_release_name" {
  description = "Helm release name for Cluster Autoscaler."
  value       = try(helm_release.cluster_autoscaler[0].name, null)
}
