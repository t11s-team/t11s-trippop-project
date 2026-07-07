# Cloud 서비스 VPC 모듈.

locals {
  # 모듈 리소스 공통 태그.
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })

  eks_service_ports = {
    for port in var.eks_service_ports : tostring(port) => port
  }

  # EKS subnet discovery 태그.
  eks_cluster_tags = {
    ("kubernetes.io/cluster/${var.eks_cluster_name}") = "shared"
  }

  create_eks_endpoints = var.enable_eks_vpc_endpoints && length(var.app_subnets) > 0
  eks_interface_services = [
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "secretsmanager",
    "sts",
  ]
}

# 기존 단일 NAT Gateway 구성을 AZ별 HA 구성의 첫 번째 AZ로 이동한다.
moved {
  from = aws_eip.nat[0]
  to   = aws_eip.nat["a"]
}

moved {
  from = aws_nat_gateway.this[0]
  to   = aws_nat_gateway.this["a"]
}

moved {
  from = aws_route_table.app
  to   = aws_route_table.app["a"]
}

moved {
  from = aws_route.app_internet_via_nat[0]
  to   = aws_route.app_internet_via_nat["a"]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-vpc-cloud"
  })
}

# ALB/NAT Gateway용 public subnet.
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.resource_tags, local.eks_cluster_tags, {
    Name = "${var.name_prefix}-subnet-cloud-public-${each.key}"

    # Public ALB subnet 태그.
    "kubernetes.io/role/elb" = "1"
  })
}

# EKS worker node용 private app subnet.
resource "aws_subnet" "app" {
  for_each = var.app_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.resource_tags, local.eks_cluster_tags, {
    Name = "${var.name_prefix}-subnet-cloud-app-${each.key}"

    # Internal ALB/NLB subnet 태그.
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-igw-cloud"
  })
}

# Public subnet용 route table.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-rt-cloud-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private app outbound용 NAT Gateway.
resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? var.public_subnets : {}

  domain = "vpc"

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-eip-nat-cloud-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? var.public_subnets : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-nat-cloud-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

# Private app subnet용 route table.
resource "aws_route_table" "app" {
  for_each = var.app_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-rt-cloud-private-app-${each.key}"
  })
}

resource "aws_route" "app_internet_via_nat" {
  for_each = var.enable_nat_gateway ? var.app_subnets : {}

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# NAT 없는 private EKS node가 AWS API에 접근하기 위한 VPC Endpoint.
resource "aws_security_group" "eks_endpoints" {
  count = local.create_eks_endpoints ? 1 : 0

  name        = "${var.name_prefix}-sg-eks-vpc-endpoints"
  description = "Interface endpoint security group for private EKS nodes."
  vpc_id      = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-sg-eks-vpc-endpoints"
  })
}

resource "aws_vpc_security_group_ingress_rule" "eks_endpoints_https_from_nodes" {
  count = local.create_eks_endpoints ? 1 : 0

  security_group_id            = aws_security_group.eks_endpoints[0].id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "HTTPS from private EKS nodes to AWS interface endpoints."
}

resource "aws_vpc_security_group_egress_rule" "eks_endpoints_all_egress" {
  count = local.create_eks_endpoints ? 1 : 0

  security_group_id = aws_security_group.eks_endpoints[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow endpoint responses."
}

resource "aws_vpc_endpoint" "eks_interface" {
  for_each = local.create_eks_endpoints ? toset(local.eks_interface_services) : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.app)[*].id
  security_group_ids  = [aws_security_group.eks_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.resource_tags, {
    Name    = "${var.name_prefix}-vpce-eks-${replace(each.value, ".", "-")}"
    Service = each.value
  })
}

resource "aws_vpc_endpoint" "eks_s3" {
  count = local.create_eks_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = values(aws_route_table.app)[*].id

  tags = merge(local.resource_tags, {
    Name    = "${var.name_prefix}-vpce-eks-s3"
    Service = "s3"
  })
}

# Cloud VPC 기본 Security Group.
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "ALB security group for public ingress."
  vpc_id      = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-sg-alb"
  })
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name_prefix}-sg-eks-nodes"
  description = "EKS worker node security group baseline."
  vpc_id      = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-sg-eks-nodes"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_http_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP access to public ALB."
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.alb_https_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS access to public ALB."
}

resource "aws_vpc_security_group_egress_rule" "alb_to_eks" {
  for_each = local.eks_service_ports

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  description                  = "ALB to EKS service port ${each.value}."
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_alb" {
  for_each = local.eks_service_ports

  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  description                  = "EKS service port ${each.value} from ALB."
}
