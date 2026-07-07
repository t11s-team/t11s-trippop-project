variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags for all resources"
}

variable "owner" {
  type        = string
  description = "Owner of the resources"
}

variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "AWS region. Used for Secrets Manager ARNs / API calls."
}

variable "db_vpc_id" {
  type        = string
  description = "VPC ID where DB security group will be created"
}

variable "eks_node_sg_id" {
  type        = string
  description = "Security group ID of the EKS worker nodes"
}

variable "admin_sg_id" {
  type        = string
  description = "Security group ID of the Admin EC2"
}

variable "db_private_subnet_id" {
  type        = string
  description = "Subnet ID where DB EC2 and EBS volume will reside"
}

variable "db_ami_id" {
  type        = string
  description = "AMI ID for the DB EC2 instance"
}

variable "db_ec2_profile_name" {
  type        = string
  description = "IAM instance profile name for DB SSM access"
}

variable "db_private_ip" {
  type        = string
  description = "Fixed private IP address for the DB EC2"
}

variable "bootstrap_prerequisite_token" {
  type        = string
  default     = ""
  description = "Opaque dependency token that changes after private endpoints, S3 artifacts, and ECR images are ready."
}

variable "db_data_volume_size" {
  type        = number
  default     = 50
  description = "Size of the database external data volume in GB"
}

variable "db_data_volume_type" {
  type        = string
  default     = "gp3"
  description = "Type of the database external data volume"
}

variable "db_backup_bucket_name" {
  type        = string
  description = "S3 bucket name for database backup uploads"
}

variable "db_artifacts_bucket_name" {
  type        = string
  description = "Private S3 bucket name containing DB bootstrap SQL artifacts."
}

variable "db_artifacts_prefix" {
  type        = string
  default     = "db/sql"
  description = "S3 key prefix for DB bootstrap SQL artifacts."
}

variable "db_name" {
  type        = string
  default     = "kculture"
  description = "Database name to create inside MariaDB Container"
}

variable "db_app_user" {
  type        = string
  default     = "admin"
  description = "Application database connection user name"
}

variable "db_app_password" {
  type        = string
  sensitive   = true
  description = "Application database user password"
}

variable "db_exporter_user" {
  type        = string
  default     = "exporter"
  description = "User name for mysqld_exporter monitoring"
}

variable "db_exporter_password" {
  type        = string
  sensitive   = true
  description = "User password for mysqld_exporter monitoring"
}

variable "mariadb_image_uri" {
  type        = string
  description = "Private ECR image URI for MariaDB, including tag."
}

variable "node_exporter_image_uri" {
  type        = string
  description = "Private ECR image URI for node-exporter, including tag."
}

variable "mysqld_exporter_image_uri" {
  type        = string
  description = "Private ECR image URI for mysqld-exporter, including tag."
}
