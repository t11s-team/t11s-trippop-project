locals {
  # 전체 모듈 공통 태그.
  common_tags = {
    Project   = var.project
    Service   = var.service
    Env       = var.env
    ManagedBy = "terraform"
  }

  db_bootstrap_artifact_files = {
    "db_init.sql"  = "${path.root}/../../../scripts/db_init.sql"
    "db_seed.sql"  = "${path.root}/../../../scripts/db_seed.sql"
    "db_reset.sql" = "${path.root}/../../../scripts/db_reset.sql"
  }

  db_runtime_images = {
    mariadb = {
      source = "mariadb:10.11"
      target = "${module.ecr.repository_urls.db_mariadb}:10.11"
    }
    node_exporter = {
      source = "quay.io/prometheus/node-exporter:v1.8.2"
      target = "${module.ecr.repository_urls.db_node_exporter}:v1.8.2"
    }
    mysqld_exporter = {
      source = "prom/mysqld-exporter:v0.15.1"
      target = "${module.ecr.repository_urls.db_mysqld_exporter}:v0.15.1"
    }
  }
}

module "cloud_vpc" {
  source = "../../modules/cloud-vpc"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "network"

  vpc_cidr           = "10.0.0.0/16"
  eks_cluster_name   = var.eks_cluster_name
  enable_nat_gateway = var.enable_nat_gateway
  region             = var.aws_region

  # ALB/EKS 기본 SG 입력값.
  alb_http_ingress_cidrs  = var.alb_http_ingress_cidrs
  alb_https_ingress_cidrs = var.alb_https_ingress_cidrs
  eks_service_ports       = var.eks_service_ports
  db_port                 = var.db_port

  public_subnets = {
    a = {
      cidr = "10.0.0.0/24"
      az   = "ap-northeast-2a"
    }
    c = {
      cidr = "10.0.1.0/24"
      az   = "ap-northeast-2c"
    }
  }

  app_subnets = {
    a = {
      cidr = "10.0.10.0/24"
      az   = "ap-northeast-2a"
    }
    c = {
      cidr = "10.0.11.0/24"
      az   = "ap-northeast-2c"
    }
  }
}

module "onprem_vpc" {
  source = "../../modules/onprem-vpc"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "network"
  region      = var.aws_region

  vpc_cidr = "172.16.0.0/16"

  # DB subnet용 VPC Endpoint 활성화.
  enable_db_vpc_endpoints = var.enable_onprem_db_vpc_endpoints

  public_subnets = {
    a = {
      cidr = "172.16.0.0/24"
      az   = "ap-northeast-2a"
    }
  }

  # 단일 DB EC2용 private subnet.
  private_db_subnets = {
    a = {
      cidr = "172.16.10.0/24"
      az   = "ap-northeast-2a"
    }
  }
}

module "peering" {
  source = "../../modules/peering"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "network"

  cloud_vpc_id   = module.cloud_vpc.vpc_id
  cloud_vpc_cidr = module.cloud_vpc.vpc_cidr

  onprem_vpc_id   = module.onprem_vpc.vpc_id
  onprem_vpc_cidr = module.onprem_vpc.vpc_cidr

  # Cloud VPC route table IDs.
  cloud_route_table_ids = module.cloud_vpc.route_table_ids

  # On-Prem VPC route table IDs.
  onprem_route_table_ids = module.onprem_vpc.route_table_ids

  # Peering 경계 SG 참조 입력값.
  admin_security_group_id = module.onprem_vpc.admin_security_group_id
  db_port                 = var.db_port
}

# EKS cluster/node group 모듈.
module "eks" {
  source = "../../modules/eks"

  cluster_name                    = var.eks_cluster_name
  cluster_version                 = var.eks_cluster_version
  cluster_security_group_name_tag = "${var.project}-${var.env}-sg-eks-cluster"
  node_role_arn                   = module.iam.eks_node_role_arn
  vpc_id                          = module.cloud_vpc.vpc_id
  subnet_ids                      = values(module.cloud_vpc.app_subnet_ids)

  # Cloud VPC의 고정 EKS node SG.
  node_security_group_ids = [
    module.cloud_vpc.eks_nodes_security_group_id
  ]

  common_tags = local.common_tags
  owner       = "eks"
}

# 서비스 이미지/업로드용 S3 모듈.
module "s3_images" {
  source = "../../modules/s3-images"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "storage"
}

# 운영 로그용 S3 모듈.
module "s3_logs" {
  source = "../../modules/s3-logs"

  name_prefix   = "${var.project}-${var.env}"
  common_tags   = local.common_tags
  owner         = "observability"
  force_destroy = false
}

# DB dump 백업용 S3 모듈.
module "s3_db_backup" {
  source = "../../modules/s3-db-backup"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "database"
}

# DB bootstrap SQL artifact용 private S3 버킷.
module "s3_db_artifacts" {
  source = "../../modules/s3-db-artifacts"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "database"
}

resource "aws_s3_object" "db_bootstrap_artifacts" {
  for_each = local.db_bootstrap_artifact_files

  bucket       = module.s3_db_artifacts.bucket_name
  key          = "db/sql/${each.key}"
  source       = each.value
  etag         = filemd5(each.value)
  content_type = "text/plain"
}

# 정적 프론트엔드 S3/CloudFront 모듈.
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "cicd"

  domain_aliases         = var.frontend_domain_aliases
  acm_certificate_arn    = var.frontend_acm_certificate_arn
  route53_hosted_zone_id = var.route53_hosted_zone_id
}

# IAM 정책/Role/IRSA 모듈.
module "iam" {
  source = "../../modules/iam"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "security"
  region      = var.aws_region

  s3_images_arn           = module.s3_images.bucket_arn
  db_backup_bucket_arn    = module.s3_db_backup.bucket_arn
  db_artifacts_bucket_arn = module.s3_db_artifacts.bucket_arn
  db_runtime_ecr_repository_arns = [
    module.ecr.repository_arns.db_mariadb,
    module.ecr.repository_arns.db_node_exporter,
    module.ecr.repository_arns.db_mysqld_exporter
  ]
  s3_frontend_arn             = module.s3_frontend.bucket_arn
  cloudfront_distribution_arn = module.s3_frontend.cloudfront_distribution_arn
  eks_cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  eks_cluster_name            = module.eks.cluster_name
  enable_eks_oidc_provider    = true
  route53_hosted_zone_id      = var.route53_hosted_zone_id
  github_repo                 = var.github_repo

  # Portfolio account IAM principals granted EKS admin access.
  eks_cluster_admin_user_arns = var.eks_cluster_admin_user_arns

  # AWS Chatbot setup IAM user permissions.
  chatbot_setup_user_names = var.chatbot_setup_user_names
}

# EKS Add-ons Helm 모듈.
module "eks_addons" {
  source = "../../modules/eks-addons"

  cluster_name                        = module.eks.cluster_name
  region                              = var.aws_region
  vpc_id                              = module.cloud_vpc.vpc_id
  lb_controller_role_arn              = module.iam.lb_controller_role_arn
  ebs_csi_driver_role_arn             = module.iam.ebs_csi_driver_role_arn
  cluster_autoscaler_role_arn         = module.iam.cluster_autoscaler_role_arn
  enable_aws_load_balancer_controller = var.enable_eks_addons
  enable_metrics_server               = var.enable_eks_addons
  enable_vpc_cni                      = var.enable_eks_default_managed_addons
  enable_coredns                      = var.enable_eks_default_managed_addons
  enable_kube_proxy                   = var.enable_eks_default_managed_addons
  enable_ebs_csi_driver               = var.enable_eks_addons
  enable_cluster_autoscaler           = var.enable_eks_addons

  depends_on = [
    module.cloud_vpc,
    module.iam,
  ]
}

# On-Prem private subnet의 EC2 DB 모듈.
module "ec2_db" {
  source = "../../modules/ec2-db"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "database"
  region      = var.aws_region

  db_vpc_id                 = module.onprem_vpc.vpc_id
  db_private_subnet_id      = module.onprem_vpc.private_db_subnet_ids["a"]
  db_private_ip             = var.ec2_db_private_ip
  eks_node_sg_id            = module.cloud_vpc.eks_nodes_security_group_id
  admin_sg_id               = module.onprem_vpc.admin_security_group_id
  db_ec2_profile_name       = module.iam.db_ec2_profile_name
  db_backup_bucket_name     = module.s3_db_backup.bucket_name
  db_artifacts_bucket_name  = module.s3_db_artifacts.bucket_name
  db_artifacts_prefix       = "db/sql"
  db_ami_id                 = var.ec2_db_ami_id
  db_app_password           = var.ec2_db_app_password
  db_exporter_password      = var.ec2_db_exporter_password
  mariadb_image_uri         = local.db_runtime_images.mariadb.target
  node_exporter_image_uri   = local.db_runtime_images.node_exporter.target
  mysqld_exporter_image_uri = local.db_runtime_images.mysqld_exporter.target
  bootstrap_prerequisite_token = sha1(join(",", compact(concat(
    values(module.onprem_vpc.db_interface_endpoint_ids),
    [module.onprem_vpc.db_s3_endpoint_id],
    [for object in aws_s3_object.db_bootstrap_artifacts : object.etag],
    [try(null_resource.mirror_db_runtime_images[0].id, "mirror-disabled")]
  ))))
}

# 애플리케이션 이미지용 ECR 모듈.
module "ecr" {
  source = "../../modules/ecr"

  name_prefix = "${var.project}-${var.env}"
  common_tags = local.common_tags
  owner       = "cicd"
}

resource "null_resource" "mirror_db_runtime_images" {
  count = var.enable_db_runtime_image_mirror ? 1 : 0

  triggers = {
    mariadb_source         = local.db_runtime_images.mariadb.source
    mariadb_target         = local.db_runtime_images.mariadb.target
    node_exporter_source   = local.db_runtime_images.node_exporter.source
    node_exporter_target   = local.db_runtime_images.node_exporter.target
    mysqld_exporter_source = local.db_runtime_images.mysqld_exporter.source
    mysqld_exporter_target = local.db_runtime_images.mysqld_exporter.target
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      set -euo pipefail
      AWS_REGION="${var.aws_region}" \
      MARIADB_SOURCE_IMAGE="${local.db_runtime_images.mariadb.source}" \
      MARIADB_TARGET_IMAGE="${local.db_runtime_images.mariadb.target}" \
      NODE_EXPORTER_SOURCE_IMAGE="${local.db_runtime_images.node_exporter.source}" \
      NODE_EXPORTER_TARGET_IMAGE="${local.db_runtime_images.node_exporter.target}" \
      MYSQLD_EXPORTER_SOURCE_IMAGE="${local.db_runtime_images.mysqld_exporter.source}" \
      MYSQLD_EXPORTER_TARGET_IMAGE="${local.db_runtime_images.mysqld_exporter.target}" \
      bash "${path.root}/../../../scripts/mirror-db-images-to-ecr.sh"
    EOT
  }

  depends_on = [module.ecr]
}

# On-Prem public subnet의 Admin EC2 모듈.
module "ec2_admin" {
  source = "../../modules/ec2-admin"

  name_prefix = "${var.project}-${var.env}"

  vpc_id              = module.onprem_vpc.vpc_id
  public_subnet_id    = module.onprem_vpc.public_subnet_ids["a"]
  admin_sg_id         = module.onprem_vpc.admin_security_group_id
  admin_ec2_role_name = module.iam.admin_ec2_role_name
}
