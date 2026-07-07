locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  # 기존 terraform.tfvars에서 참조하던 Role 이름과 동일하게 생성한다.
  # 이 Role이 없으면 EKS Node Group 생성 시 AWS가 클러스터 Role을 찾지 못해 실패한다.
  name               = var.cluster_name
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "t11s_eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn

  version                       = var.cluster_version
  bootstrap_self_managed_addons = var.bootstrap_self_managed_addons

  access_config {
    # Access Entry API로 클러스터 접근을 관리한다. aws-auth ConfigMap은 사용하지 않는다.
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = local.resource_tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

resource "aws_ec2_tag" "cluster_security_group_name" {
  resource_id = aws_eks_cluster.t11s_eks.vpc_config[0].cluster_security_group_id
  key         = "Name"
  value       = var.cluster_security_group_name_tag
}

resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  # DB SG와 ALB SG가 EKS 자동 생성 SG가 아니라 Terraform에서 관리하는 고정 SG를 참조할 수 있게 한다.
  # 단, EKS 기본 통신을 깨지 않기 위해 AWS가 클러스터에 생성한 SG도 함께 노드에 유지한다.
  vpc_security_group_ids = distinct(concat(
    var.node_security_group_ids,
    [aws_eks_cluster.t11s_eks.vpc_config[0].cluster_security_group_id]
  ))

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.resource_tags, {
      Name = "${var.cluster_name}-node"
    })
  }

  tags = merge(local.resource_tags, {
    Name = "${var.cluster_name}-node-lt"
  })
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.t11s_eks.name
  node_group_name = "${var.cluster_name}-nodegroup"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = "SPOT"
  instance_types = ["c5.large"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  tags = merge(local.resource_tags, {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  })

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  depends_on = [aws_eks_cluster.t11s_eks]
}
