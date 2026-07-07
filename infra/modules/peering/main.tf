# Cloud-OnPrem VPC Peering 모듈.

locals {
  # 모듈 리소스 공통 태그.
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.cloud_vpc_id
  peer_vpc_id = var.onprem_vpc_id

  # 같은 계정/리전 peering 자동 승인.
  auto_accept = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-pcx-cloud-onprem"
  })
}

# Peering DNS resolution 옵션.
resource "aws_vpc_peering_connection_options" "this" {
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

# Cloud VPC에서 On-Prem CIDR로 가는 route.
resource "aws_route" "cloud_to_onprem" {
  for_each = var.cloud_route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.onprem_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# On-Prem VPC에서 Cloud CIDR로 가는 route.
resource "aws_route" "onprem_to_cloud" {
  for_each = var.onprem_route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.cloud_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

