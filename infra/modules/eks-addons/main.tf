resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "image.tag"
    value = var.aws_load_balancer_controller_image_tag
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lb_controller_role_arn
  }

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
  ]
}

# metrics-server: HPA가 CPU/메모리 metric을 읽기 위한 필수 add-on.
# 미설치 시 HPA가 metric을 <unknown>으로 읽어 오토스케일이 전면 불가.
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  # EKS 노드는 InternalIP로 kubelet에 접근해야 metric scrape가 성공.
  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [
    aws_eks_addon.coredns,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_vpc_cni ? 1 : 0

  cluster_name  = var.cluster_name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_addon_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_kube_proxy ? 1 : 0

  cluster_name  = var.cluster_name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_addon_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_coredns ? 1 : 0

  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.coredns_addon_version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}

# 모니터링 PVC에 필요한 EBS 볼륨을 동적으로 프로비저닝한다.
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_addon_version
  service_account_role_arn = var.ebs_csi_driver_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
  ]
}

# HPA로 Pending 상태가 된 Pod를 수용하도록 Managed Node Group을 확장한다.
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler_chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  depends_on = [
    aws_eks_addon.coredns,
    helm_release.aws_load_balancer_controller,
  ]

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_role_arn
  }
}
