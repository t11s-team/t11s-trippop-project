variable "name_prefix" {
  description = "AWS 리소스 접두사 (팀 컨벤션 반영)"
  type        = string
  default     = "t11s-dev"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public Subnet ID (EC2가 배치될 서브넷)"
  type        = string
}

variable "admin_sg_id" {
  description = "Admin EC2용 Security Group ID"
  type        = string
}

variable "admin_ec2_role_name" {
  description = "인스턴스 프로파일에 연결할 Admin용 IAM Role 이름"
  type        = string
}