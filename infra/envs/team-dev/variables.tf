variable "aws_region" {
  description = "AWS region for team dev environment."
  type        = string
  default     = "ap-northeast-2"
}

variable "env" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Short project/team prefix used in tags and names."
  type        = string
  default     = "t11s"
}

variable "service" {
  description = "Service name for common tags."
  type        = string
  default     = "k-culture-booking"
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for subnet discovery tags."
  type        = string
  default     = "t11s-dev-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "eks_cluster_role_arn" {
  description = "Deprecated. Kept only so existing local terraform.tfvars does not fail; the EKS module now creates the cluster role."
  type        = string
  default     = null
}

variable "alb_http_ingress_cidrs" {
  description = "CIDR blocks allowed to access ALB over HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_https_ingress_cidrs" {
  description = "CIDR blocks allowed to access ALB over HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_service_ports" {
  description = "Service ports allowed from ALB SG to EKS/App SG. reservation=3001, event=3002, user=3003, admin=3004."
  type        = list(number)
  default     = [3001, 3002, 3003, 3004]
}

variable "db_port" {
  description = "Database port used by DB access rules. Current target is On-Prem EC2 DB."
  type        = number
  default     = 3306
}

variable "enable_nat_gateway" {
  description = "Whether to create one NAT Gateway per Cloud public subnet/AZ for private app subnet outbound. Keep false until cost approval."
  type        = bool
  default     = false
}

variable "enable_onprem_db_vpc_endpoints" {
  description = "Create SSM/SecretsManager/S3/ECR/CloudWatch Logs VPC Endpoints so the private DB EC2 reaches AWS APIs without a NAT Gateway. Recommended; keep true."
  type        = bool
  default     = true
}

variable "enable_db_runtime_image_mirror" {
  description = "Mirror MariaDB/node-exporter/mysqld-exporter public images into private ECR during terraform apply."
  type        = bool
  default     = true
}

variable "enable_eks_addons" {
  description = "Whether to install EKS add-ons such as aws-load-balancer-controller through Helm."
  type        = bool
  default     = false
}

variable "enable_eks_default_managed_addons" {
  description = "Whether to manage default EKS add-ons such as vpc-cni, coredns, and kube-proxy through Terraform."
  type        = bool
  default     = true
}

variable "ec2_db_ami_id" {
  description = "Golden AMI ID for On-Prem DB EC2. It must include Docker, AWS CLI, cron, curl, and amazon-ssm-agent for NAT-less bootstrap."
  type        = string
  default     = null

  validation {
    condition     = var.ec2_db_ami_id != null && can(regex("^ami-[0-9a-f]+$", var.ec2_db_ami_id))
    error_message = "ec2_db_ami_id must be set to a DB Golden AMI ID. Build infra/packer/db-golden-ami.pkr.hcl first, then pass the resulting AMI ID."
  }
}

variable "ec2_db_private_ip" {
  description = "Fixed private IP for On-Prem DB EC2. Keep stable so Kubernetes DB_HOST does not change after replacement."
  type        = string
  default     = "172.16.10.122"
}

variable "ec2_db_app_password" {
  description = "Application database user password for On-Prem EC2 DB. Provide through tfvars or TF_VAR_ec2_db_app_password."
  type        = string
  sensitive   = true
}

variable "ec2_db_exporter_password" {
  description = "mysqld_exporter database user password for On-Prem EC2 DB. Provide through tfvars or TF_VAR_ec2_db_exporter_password."
  type        = string
  sensitive   = true
}

variable "frontend_domain_aliases" {
  description = "Custom domain names for the frontend CloudFront distribution. Empty uses the default *.cloudfront.net domain only."
  type        = list(string)
  default     = []
}

variable "frontend_acm_certificate_arn" {
  description = "ACM certificate ARN for frontend_domain_aliases. MUST be issued in us-east-1 (CloudFront requirement). Leave null when no custom domain is used."
  type        = string
  default     = null
}

variable "api_domain_name" {
  description = "Custom domain name for the public API ingress. Provide through terraform.tfvars or TF_VAR_api_domain_name for CD secret sync."
  type        = string
  default     = ""
}

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for the public API ingress. Provide through terraform.tfvars or TF_VAR_api_acm_certificate_arn for CD secret sync."
  type        = string
  default     = ""
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID for frontend aliases and API DNS automation. Empty disables related resources."
  type        = string
  default     = ""
}

variable "eks_cluster_admin_user_arns" {
  description = "IAM principal ARNs granted EKS cluster admin access through EKS Access Entry API."
  type        = list(string)
  default     = []
}

variable "chatbot_setup_user_names" {
  description = "IAM user names allowed to configure AWS Chatbot Slack notification integration."
  type        = list(string)
  default     = []
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the GitHub Actions OIDC role, format org/repo."
  type        = string
  default     = "ahzldut/t11s-trippop-msa"
}
