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

variable "vpc_cidr" {
  description = "CIDR block for Cloud VPC."
  type        = string
}

variable "public_subnets" {
  description = "Public subnet definitions keyed by short AZ name."
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "app_subnets" {
  description = "Private app subnet definitions keyed by short AZ name."
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for Kubernetes subnet discovery tags. Update with Kubernetes owner before EKS apply."
  type        = string
  default     = "t11s-dev-eks"
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private app subnet outbound. When enabled, one NAT Gateway is created per public subnet/AZ."
  type        = bool
  default     = false
}

variable "enable_eks_vpc_endpoints" {
  description = "Create VPC endpoints for private EKS nodes so AWS APIs remain reachable without a NAT Gateway."
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region used for VPC endpoint service names."
  type        = string
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
  description = "Database port used by DB-related SG rules. EC2 DB access is managed by the ec2-db module."
  type        = number
  default     = 3306
}
