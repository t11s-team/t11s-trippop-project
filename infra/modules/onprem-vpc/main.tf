# On-Prem Simulation VPC 모듈.

locals {
  # 모듈 리소스 공통 태그.
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-vpc-onprem"
  })
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-subnet-onprem-public-${each.key}"
  })
}

# DB EC2용 private subnet.
resource "aws_subnet" "private_db" {
  for_each = var.private_db_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-subnet-onprem-db-${each.key}"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-igw-onprem"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-rt-onprem-public"
  })
}

# On-Prem public subnet 인터넷 route.
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

# DB private subnet용 route table.
resource "aws_route_table" "private_db" {
  count = length(var.private_db_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-rt-onprem-private-db"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[0].id
}

# Admin EC2용 Security Group.
resource "aws_security_group" "admin" {
  name        = "${var.name_prefix}-sg-admin"
  description = "Admin EC2 security group baseline. No SSH inbound; use SSM."
  vpc_id      = aws_vpc.this.id

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-sg-admin"
  })
}

# Admin EC2 outbound HTTPS rule.
resource "aws_vpc_security_group_egress_rule" "admin_https_to_aws_apis" {
  security_group_id = aws_security_group.admin.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Admin outbound HTTPS for SSM Session Manager and Translate API."
}

# DB EC2용 VPC Endpoint.
locals {
  create_db_endpoints   = var.enable_db_vpc_endpoints && length(var.private_db_subnets) > 0
  db_interface_services = ["ssm", "ssmmessages", "ec2messages", "secretsmanager", "ecr.api", "ecr.dkr", "logs"]
}

# Interface Endpoint용 Security Group.
resource "aws_security_group" "vpce" {
  count = local.create_db_endpoints ? 1 : 0

  name        = "${var.name_prefix}-onprem-vpce-sg"
  description = "Allow HTTPS from VPC to interface VPC endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from within the On-Prem VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-onprem-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "db_interface" {
  for_each = local.create_db_endpoints ? toset(local.db_interface_services) : []

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private_db : s.id]
  security_group_ids  = [aws_security_group.vpce[0].id]
  private_dns_enabled = true

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-vpce-${each.value}"
  })
}

# DB subnet용 S3 Gateway Endpoint.
resource "aws_vpc_endpoint" "db_s3" {
  count = local.create_db_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_db[0].id]

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-vpce-s3"
  })
}
