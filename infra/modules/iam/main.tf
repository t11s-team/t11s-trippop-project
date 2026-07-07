locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
  oidc_url_stripped = var.eks_cluster_oidc_issuer_url != "" ? replace(var.eks_cluster_oidc_issuer_url, "https://", "") : ""
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "tls_certificate" "eks_cluster" {
  count = var.enable_eks_oidc_provider ? 1 : 0
  url   = var.eks_cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.enable_eks_oidc_provider ? 1 : 0
  url             = var.eks_cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster[0].certificates[0].sha1_fingerprint]
}

# H2 수정: s3:* / translate:* (Resource:"*") 전체 권한을 실제 사용처로 축소한다.
# 사용처: 앱 워크로드(images 버킷 r/w), 번역(admin-service), CI 프론트 배포(frontend 버킷 sync --delete),
#         관리/백업 운영(db_backup 버킷). 버킷 정책/ACL/버킷 삭제 같은 위험 동작은 제외한다.
resource "aws_iam_policy" "app_combined_access" {
  name        = "${var.name_prefix}-app-combined-policy"
  description = "Least-privilege S3 (object) + Translate access for app/admin/CI roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ObjectReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.s3_images_arn}/*",
          "${var.s3_frontend_arn}/*",
          "${var.db_backup_bucket_arn}/*"
        ]
      },
      {
        Sid    = "S3BucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_images_arn,
          var.s3_frontend_arn,
          var.db_backup_bucket_arn
        ]
      },
      {
        Sid      = "TranslateText"
        Effect   = "Allow"
        Action   = ["translate:TranslateText"]
        Resource = "*" # Translate는 리소스 단위 제한을 지원하지 않음
      }
    ]
  })
}

# CI의 CloudFront 배포 조회와 캐시 무효화 전용 최소 권한. app_role에만 부여한다.
resource "aws_iam_policy" "cloudfront_invalidation" {
  name        = "${var.name_prefix}-cloudfront-invalidation-policy"
  description = "Allow CI to create CloudFront cache invalidations for the frontend distribution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution"
        ]
        Resource = var.cloudfront_distribution_arn
      }
    ]
  })
}

# CI가 새 ALB DNS를 api 도메인 Route53 레코드에 반영한다.
resource "aws_iam_policy" "route53_api_record_update" {
  count = var.route53_hosted_zone_id != "" ? 1 : 0

  name        = "${var.name_prefix}-route53-api-record-update-policy"
  description = "Allow CI to update API Route53 record for the current ALB DNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"
      }
    ]
  })
}

# GitHub Actions CD가 Kubernetes DB Secret을 생성할 때 DB password만 읽을 수 있게 한다.
resource "aws_iam_policy" "app_db_secret_read" {
  name        = "${var.name_prefix}-app-db-secret-read-policy"
  description = "Allow GitHub Actions CD to read DB password for Kubernetes Secret creation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.name_prefix}-db-app-password-*"
      }
    ]
  })
}

resource "aws_iam_policy" "db_backup_access" {
  name        = "${var.name_prefix}-db-backup-policy"
  description = "Minimum permissions for DB backup to S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.db_backup_bucket_arn}",
          "${var.db_backup_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "app_eks_describe" {
  name        = "${var.name_prefix}-app-eks-describe-policy"
  description = "Policy to allow describing the EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.region}:*:cluster/${var.name_prefix}-eks"
      }
    ]
  })
}

resource "aws_iam_role" "admin_ec2" {
  name = "${var.name_prefix}-admin-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "admin_ssm" {
  role       = aws_iam_role.admin_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "admin_app_combined" {
  role       = aws_iam_role.admin_ec2.name
  policy_arn = aws_iam_policy.app_combined_access.arn
}

resource "aws_iam_role" "db_ec2" {
  name = "${var.name_prefix}-db-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "db_ssm" {
  role       = aws_iam_role.db_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "db_backup" {
  role       = aws_iam_role.db_ec2.name
  policy_arn = aws_iam_policy.db_backup_access.arn
}

# DB EC2가 MariaDB 자격증명(${name_prefix}-db-*)만 Secrets Manager에서 조회한다.
# 폐쇄망 구성에서는 GitHub clone을 제거하므로 GitHub token 접근 권한을 부여하지 않는다.
resource "aws_iam_policy" "db_secrets_read" {
  name        = "${var.name_prefix}-db-secrets-read-policy"
  description = "Allow DB EC2 to read its MariaDB credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.name_prefix}-db-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_secrets_read" {
  role       = aws_iam_role.db_ec2.name
  policy_arn = aws_iam_policy.db_secrets_read.arn
}

resource "aws_iam_policy" "db_artifacts_read" {
  name        = "${var.name_prefix}-db-artifacts-read-policy"
  description = "Allow DB EC2 to read SQL bootstrap artifacts from private S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.db_artifacts_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.db_artifacts_bucket_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_artifacts_read" {
  role       = aws_iam_role.db_ec2.name
  policy_arn = aws_iam_policy.db_artifacts_read.arn
}

resource "aws_iam_policy" "db_ecr_pull" {
  count = length(var.db_runtime_ecr_repository_arns) > 0 ? 1 : 0

  name        = "${var.name_prefix}-db-ecr-pull-policy"
  description = "Allow DB EC2 to pull MariaDB and exporter images from private ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = var.db_runtime_ecr_repository_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_ecr_pull" {
  count = length(var.db_runtime_ecr_repository_arns) > 0 ? 1 : 0

  role       = aws_iam_role.db_ec2.name
  policy_arn = aws_iam_policy.db_ecr_pull[0].arn
}

resource "aws_iam_instance_profile" "db_ec2_profile" {
  name = "${var.name_prefix}-db-ec2-profile"
  role = aws_iam_role.db_ec2.name
}

resource "aws_iam_role" "app_role" {
  name = "${var.name_prefix}-app-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = ["ec2.amazonaws.com", "eks.amazonaws.com"] }
      },
      {
        Action    = "sts:AssumeRoleWithWebIdentity"
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "app_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_combined_access.arn
}

resource "aws_iam_role_policy_attachment" "app_eks_describe_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_eks_describe.arn
}

resource "aws_iam_role_policy_attachment" "app_cloudfront_invalidation" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.cloudfront_invalidation.arn
}

resource "aws_iam_role_policy_attachment" "app_route53_api_record_update" {
  count = var.route53_hosted_zone_id != "" ? 1 : 0

  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.route53_api_record_update[0].arn
}

resource "aws_iam_role_policy_attachment" "app_db_secret_read" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_db_secret_read.arn
}

resource "aws_iam_role" "eks_node" {
  name = "${var.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.name_prefix}-lb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com",
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# H3 수정: 정책을 'main' 브랜치에서 매 apply마다 가져오면 상류 변경이 IAM 정책을
# 조용히 바꾼다(공급망 위험 + 비결정성). 고정된 릴리스 태그로 핀한다.
# 더 강한 보장이 필요하면 이 JSON을 레포에 vendoring 하고 file()로 읽도록 바꾼다.
data "http" "lb_controller_policy_json" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.lb_controller_policy_version}/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lb_controller_policy" {
  name   = "${var.name_prefix}-lb-controller-policy"
  policy = data.http.lb_controller_policy_json.response_body
}

resource "aws_iam_role_policy_attachment" "lb_controller_attach" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

resource "aws_iam_policy" "lb_controller_elb_describe_policy" {
  name        = "${var.name_prefix}-lb-controller-elb-describe-policy"
  description = "Supplemental ELB describe permissions required by AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller_elb_describe_attach" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller_elb_describe_policy.arn
}

# EBS CSI Controller가 EBS 볼륨을 생성하고 연결하기 위한 IRSA Role.
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.name_prefix}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com",
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Cluster Autoscaler가 EKS Managed Node Group의 ASG 크기를 조정하기 위한 IRSA Role.
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.name_prefix}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com",
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
        }
      }
    }]
  })

  tags = local.resource_tags
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.name_prefix}-cluster-autoscaler-policy"
  description = "Allow Cluster Autoscaler to discover and resize the tagged EKS managed node group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScaleTaggedNodeGroups"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"                 = "true"
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.eks_cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "DiscoverNodeGroups"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_iam_role" "fluent_bit" {
  name = "${var.name_prefix}-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${local.oidc_url_stripped}:aud" = "sts.amazonaws.com",
          # install-helm-stack.yml 이 aws-for-fluent-bit 차트를 kube-system 네임스페이스에
          # SA 이름 aws-for-fluent-bit 로 배포한다. IRSA 의 sub 클레임이 정확히
          # system:serviceaccount:<ns>:<sa> 와 일치해야 AssumeRoleWithWebIdentity 가 성공한다.
          "${local.oidc_url_stripped}:sub" = "system:serviceaccount:kube-system:aws-for-fluent-bit"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "fluent_bit_cloudwatch_logs" {
  name        = "${var.name_prefix}-fluent-bit-cloudwatch-logs-policy"
  description = "Allow Fluent Bit to create and write EKS application log groups and streams"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteEKSApplicationLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/eks/${var.name_prefix}/*:*"
      },
      {
        Sid    = "DescribeCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit_cloudwatch_logs" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit_cloudwatch_logs.arn
}

resource "aws_iam_policy" "ecr_push" {
  name = "${var.name_prefix}-ecr-push-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${var.region}:*:repository/${var.name_prefix}-ecr-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_ecr_push" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

data "aws_caller_identity" "current" {}

locals {
  # EKS creates an access entry for the cluster creator when
  # bootstrap_cluster_creator_admin_permissions=true. Managing that same
  # principal here causes CreateAccessEntry 409 after every destroy/apply cycle.
  managed_eks_cluster_admin_user_arns = toset([
    for arn in var.eks_cluster_admin_user_arns : arn
    if arn != data.aws_caller_identity.current.arn
  ])
}

resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.app_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = aws_eks_access_entry.github_actions.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.github_actions.principal_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "team_users" {
  for_each = local.managed_eks_cluster_admin_user_arns

  cluster_name  = var.eks_cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "team_users_admin" {
  for_each = aws_eks_access_entry.team_users

  cluster_name  = each.value.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_policy" "cw_sns_alerts_policy" {
  name        = "${var.name_prefix}-cw-sns-alerts-policy"
  description = "Minimum permissions for CloudWatch Alarms and SNS Slack Notification (Deliverable: 5/26)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchAlarmManagement"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsInspection"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:*:log-group:/aws/containerinsights/${var.name_prefix}-*/*",
          "arn:aws:logs:${var.region}:*:log-group:${var.name_prefix}-*"
        ]
      },
      {
        Sid    = "SNSAlertsManagement"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:Subscribe",
          "sns:Publish",
          "sns:ListTopics"
        ]
        Resource = [
          "arn:aws:sns:${var.region}:*:kculture-alerts-*"
        ]
      }
    ]
  })

  tags = local.resource_tags
}

resource "aws_iam_policy" "chatbot_setup" {
  name        = "${var.name_prefix}-chatbot-setup-policy"
  description = "Permissions for monitoring owner to configure AWS Chatbot Slack notifications."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowChatbotSetup"
        Effect = "Allow"
        Action = [
          "chatbot:RedeemSlackOauthCode",
          "chatbot:DescribeSlackWorkspaces",
          "chatbot:DescribeSlackChannelConfigurations",
          "chatbot:CreateSlackChannelConfiguration",
          "chatbot:UpdateSlackChannelConfiguration",
          "chatbot:DeleteSlackChannelConfiguration",
          "chatbot:DescribeSlackUserIdentities",
          "chatbot:GetAccountPreferences"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowChatbotIAMRoleCreate"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:AttachRolePolicy",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kculture-chatbot-*"
      }
    ]
  })

  tags = local.resource_tags
}

resource "aws_iam_user_policy_attachment" "chatbot_setup_users" {
  for_each = toset(var.chatbot_setup_user_names)

  user       = each.value
  policy_arn = aws_iam_policy.chatbot_setup.arn
}

resource "aws_iam_role_policy_attachment" "admin_cw_alerts" {
  role       = aws_iam_role.admin_ec2.name
  policy_arn = aws_iam_policy.cw_sns_alerts_policy.arn
}

resource "aws_iam_role_policy_attachment" "db_cw_alerts" {
  role       = aws_iam_role.db_ec2.name
  policy_arn = aws_iam_policy.cw_sns_alerts_policy.arn
}
