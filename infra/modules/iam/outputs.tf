output "admin_ec2_role_name" {
  description = "Name of the IAM role for Admin EC2 access"
  value       = aws_iam_role.admin_ec2.name
}

output "app_role_arn" {
  description = "ARN of the IAM role for application services"
  value       = aws_iam_role.app_role.arn
}

output "app_role_name" {
  description = "Name of the IAM role for application services"
  value       = aws_iam_role.app_role.name
}

output "db_ec2_profile_name" {
  description = "Name of the IAM instance profile for DB EC2"
  value       = aws_iam_instance_profile.db_ec2_profile.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "eks_oidc_provider_arn" {
  description = "IAM 모듈에서 직접 생성한 EKS OIDC Provider의 ARN"
  value       = length(aws_iam_openid_connect_provider.eks) > 0 ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "eks_node_role_arn" {
  description = "EKS Worker Node 그룹 생성 시 필요한 Role ARN"
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  description = "EKS Worker Node Role Name"
  value       = aws_iam_role.eks_node.name
}

output "lb_controller_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller."
  value       = aws_iam_role.lb_controller.arn
}

output "lb_controller_role_name" {
  description = "IRSA role name for aws-load-balancer-controller."
  value       = aws_iam_role.lb_controller.name
}

output "ebs_csi_driver_role_arn" {
  description = "IRSA role ARN for the Amazon EBS CSI Driver."
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "iam_boundary_arn" {
  description = "ARN of the IAM Permissions Boundary"
  value       = null
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for aws-for-fluent-bit. GitHub Secret FLUENTBIT_ROLE_ARN 에 이 값을 등록한다."
  value       = aws_iam_role.fluent_bit.arn
}
