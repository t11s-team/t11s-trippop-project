output "cloud_vpc_id" {
  description = "Cloud service VPC ID."
  value       = module.cloud_vpc.vpc_id
}

output "cloud_public_subnet_ids" {
  description = "Cloud public subnet IDs for ALB and NAT Gateway."
  value       = module.cloud_vpc.public_subnet_ids
}

output "cloud_app_subnet_ids" {
  description = "Cloud private app subnet IDs for EKS worker nodes."
  value       = module.cloud_vpc.app_subnet_ids
}

output "onprem_vpc_id" {
  description = "On-Prem simulation VPC ID."
  value       = module.onprem_vpc.vpc_id
}

output "onprem_public_subnet_ids" {
  description = "On-Prem public subnet IDs for Admin EC2."
  value       = module.onprem_vpc.public_subnet_ids
}

output "vpc_peering_connection_id" {
  description = "Cloud <-> On-Prem VPC peering connection ID."
  value       = module.peering.vpc_peering_connection_id
}

output "cloud_route_table_ids" {
  description = "Route table IDs in Cloud VPC."
  value       = module.cloud_vpc.route_table_ids
}

output "cloud_nat_gateway_id" {
  description = "First NAT Gateway ID when NAT is enabled. Null when disabled."
  value       = module.cloud_vpc.nat_gateway_id
}

output "cloud_nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by AZ when NAT is enabled."
  value       = module.cloud_vpc.nat_gateway_ids
}

output "cloud_nat_eip_public_ip" {
  description = "First Elastic IP public address for NAT Gateway when NAT is enabled. Null when disabled."
  value       = module.cloud_vpc.nat_eip_public_ip
}

output "cloud_nat_eip_public_ips" {
  description = "Elastic IP public addresses for NAT Gateways keyed by AZ when NAT is enabled."
  value       = module.cloud_vpc.nat_eip_public_ips
}

output "onprem_route_table_ids" {
  description = "Route table IDs in On-Prem VPC."
  value       = module.onprem_vpc.route_table_ids
}

output "security_group_ids" {
  description = "Baseline security group IDs for ALB, EKS, and Admin."
  value       = merge(module.cloud_vpc.security_group_ids, module.onprem_vpc.security_group_ids)
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_role_arn" {
  description = "EKS cluster service role ARN."
  value       = module.eks.cluster_role_arn
}

output "eks_cluster_role_name" {
  description = "EKS cluster service role name."
  value       = module.eks.cluster_role_name
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID actually attached to worker nodes."
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_issuer_url" {
  description = "EKS OIDC issuer URL with https:// prefix."
  value       = module.eks.oidc_issuer_url
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL with https:// prefix for IAM module integration."
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_oidc_issuer_hostpath" {
  description = "EKS OIDC issuer host/path without https:// prefix."
  value       = module.eks.oidc_issuer_hostpath
}

output "eks_node_group_name" {
  description = "EKS managed node group name."
  value       = module.eks.node_group_name
}

output "eks_node_group_status" {
  description = "EKS managed node group status."
  value       = module.eks.node_group_status
}

output "s3_images_bucket_name" {
  description = "S3 images bucket name."
  value       = module.s3_images.bucket_name
}

output "s3_images_bucket_arn" {
  description = "S3 images bucket ARN."
  value       = module.s3_images.bucket_arn
}

output "s3_logs_bucket_name" {
  description = "S3 logs bucket name."
  value       = module.s3_logs.bucket_name
}

output "s3_logs_bucket_arn" {
  description = "S3 logs bucket ARN."
  value       = module.s3_logs.bucket_arn
}

output "s3_logs_bucket_id" {
  description = "S3 logs bucket ID."
  value       = module.s3_logs.bucket_id
}

output "s3_db_backup_bucket_name" {
  description = "S3 DB backup bucket name."
  value       = module.s3_db_backup.bucket_name
}

output "s3_db_backup_bucket_arn" {
  description = "S3 DB backup bucket ARN."
  value       = module.s3_db_backup.bucket_arn
}

output "s3_db_artifacts_bucket_name" {
  description = "S3 DB bootstrap artifacts bucket name."
  value       = module.s3_db_artifacts.bucket_name
}

output "s3_db_artifacts_bucket_arn" {
  description = "S3 DB bootstrap artifacts bucket ARN."
  value       = module.s3_db_artifacts.bucket_arn
}

output "s3_frontend_bucket_name" {
  description = "S3 frontend bucket name for static frontend build artifacts."
  value       = module.s3_frontend.bucket_name
}

output "s3_frontend_bucket_arn" {
  description = "S3 frontend bucket ARN for CloudFront and CI/CD integration."
  value       = module.s3_frontend.bucket_arn
}

output "frontend_cloudfront_distribution_id" {
  description = "Frontend CloudFront distribution ID. Set as GitHub secret CLOUDFRONT_DISTRIBUTION_ID for CI/CD cache invalidation."
  value       = module.s3_frontend.cloudfront_distribution_id
}

output "frontend_cloudfront_domain_name" {
  description = "Frontend CloudFront domain name (*.cloudfront.net). Public URL when no custom domain is configured."
  value       = module.s3_frontend.cloudfront_domain_name
}

output "frontend_cloudfront_hosted_zone_id" {
  description = "Frontend CloudFront hosted zone ID for Route53 alias records when using a custom domain."
  value       = module.s3_frontend.cloudfront_hosted_zone_id
}

output "frontend_domain_name" {
  description = "Primary frontend custom domain name used by CD for CORS and frontend public URL. Empty when no custom alias is configured."
  value       = length(var.frontend_domain_aliases) > 0 ? var.frontend_domain_aliases[0] : ""
}

output "api_domain_name" {
  description = "Public API custom domain name used by CD for ingress host, frontend API base URL, and Route53 API record."
  value       = var.api_domain_name
}

output "api_acm_certificate_arn" {
  description = "ACM certificate ARN used by the public API ALB ingress. Synchronized to GitHub Secrets for deployment-time manifest rendering."
  value       = var.api_acm_certificate_arn
  sensitive   = true
}

output "iam_app_role_arn" {
  description = "IAM role ARN for application services."
  value       = module.iam.app_role_arn
}

output "iam_app_role_name" {
  description = "IAM role name for application services."
  value       = module.iam.app_role_name
}

output "iam_lb_controller_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller."
  value       = module.iam.lb_controller_role_arn
}

output "iam_fluent_bit_role_arn" {
  description = "IRSA role ARN for aws-for-fluent-bit. Set as GitHub secret FLUENTBIT_ROLE_ARN for the install-helm-stack workflow."
  value       = module.iam.fluent_bit_role_arn
}

# output "eks_addons_aws_load_balancer_controller_release_name" {
#   description = "Helm release name for aws-load-balancer-controller."
#   value       = module.eks_addons.aws_load_balancer_controller_release_name
# }

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN."
  value       = module.iam.github_oidc_provider_arn
}

output "iam_boundary_arn" {
  description = "IAM permissions boundary ARN."
  value       = module.iam.iam_boundary_arn
}

output "ec2_db_private_ip" {
  description = "Private IP address of the On-Prem DB EC2 instance."
  value       = module.ec2_db.db_private_ip
}

output "ec2_db_instance_name" {
  description = "Name tag value of the On-Prem DB EC2 instance."
  value       = "${var.project}-${var.env}-ec2-db"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs by service key for CI/CD image push and EKS image pull."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs by service key for IAM policy integration."
  value       = module.ecr.repository_arns
}

output "ecr_repository_names" {
  description = "ECR repository names by service key."
  value       = module.ecr.repository_names
}

output "db_runtime_image_uris" {
  description = "Private ECR image URIs used by the DB EC2 bootstrap."
  value = {
    mariadb         = local.db_runtime_images.mariadb.target
    node_exporter   = local.db_runtime_images.node_exporter.target
    mysqld_exporter = local.db_runtime_images.mysqld_exporter.target
  }
}
