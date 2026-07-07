# [요청사항 반영] Admin EC2용 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "admin_ec2" {
  name = "${var.name_prefix}-admin-ec2-profile"
  role = var.admin_ec2_role_name
}

# 1. Amazon Linux 2023 최신 AMI를 동적으로 가져오는 데이터 소스 추가
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 2. Admin EC2 인스턴스
resource "aws_instance" "admin" {
  ami           = data.aws_ami.al2023.id # 하드코딩된 ID 대신 데이터 소스 ID 참조로 변경
  instance_type = "t3.micro"

  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.admin_sg_id]

  # 위에서 생성한 프로파일을 자동으로 연결
  iam_instance_profile = aws_iam_instance_profile.admin_ec2.name

  associate_public_ip_address = true

  tags = {
    Name = "${var.name_prefix}-ec2-admin"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              EOF
}

# 3. 고정 IP (EIP) 할당
resource "aws_eip" "admin_eip" {
  instance = aws_instance.admin.id
  domain   = "vpc"

  tags = {
    Name = "${var.name_prefix}-eip-admin"
  }
}
