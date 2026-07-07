# 1. 클러스터 이름
output "cluster_name" {
  value = aws_eks_cluster.t11s_eks.name
}

# 2. 클러스터 엔드포인트 주소
output "cluster_endpoint" {
  value = aws_eks_cluster.t11s_eks.endpoint
}

# 3. 클러스터 인증 데이터
output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.t11s_eks.certificate_authority[0].data
}

output "cluster_role_arn" {
  description = "EKS cluster service role ARN."
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "EKS cluster service role name."
  value       = aws_iam_role.cluster.name
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID created by AWS."
  value       = aws_eks_cluster.t11s_eks.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL with https:// prefix."
  value       = aws_eks_cluster.t11s_eks.identity[0].oidc[0].issuer
}

output "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL with https:// prefix. Kept for IAM module integration."
  value       = aws_eks_cluster.t11s_eks.identity[0].oidc[0].issuer
}

output "oidc_issuer_hostpath" {
  description = "EKS OIDC issuer host/path without https:// prefix. Use this value for IAM trust policy condition keys."
  value       = replace(aws_eks_cluster.t11s_eks.identity[0].oidc[0].issuer, "https://", "")
}

output "node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "node_group_status" {
  value = aws_eks_node_group.main.status
}
