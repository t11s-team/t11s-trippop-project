packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name_prefix" {
  type    = string
  default = "t11s-dev"
}

variable "preload_public_images" {
  type    = bool
  default = true
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "db_golden" {
  region        = var.aws_region
  instance_type = "t3.small"
  ssh_username  = "ec2-user"
  ami_name      = "${var.name_prefix}-db-golden-${local.timestamp}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  tags = {
    Name      = "${var.name_prefix}-db-golden"
    Project   = "t11s"
    Env       = "dev"
    ManagedBy = "packer"
    Role      = "Database-Container-Host"
  }
}

build {
  sources = ["source.amazon-ebs.db_golden"]

  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "sudo dnf update -y",
      "sudo dnf install -y docker cronie crontabs amazon-ssm-agent awscli jq tar gzip shadow-utils",
      "command -v curl",
      "sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl enable docker",
      "sudo systemctl enable crond",
      "sudo usermod -aG docker ec2-user || true",
      "sudo dnf remove -y git || true",
      "sudo dnf clean all"
    ]
  }

  provisioner "shell" {
    only = ["amazon-ebs.db_golden"]
    environment_vars = [
      "PRELOAD_PUBLIC_IMAGES=${var.preload_public_images}"
    ]
    inline = [
      "set -euo pipefail",
      "if [ \"$PRELOAD_PUBLIC_IMAGES\" != \"true\" ]; then exit 0; fi",
      "sudo systemctl start docker",
      "sudo docker pull mariadb:10.11",
      "sudo docker pull quay.io/prometheus/node-exporter:v1.8.2",
      "sudo docker pull prom/mysqld-exporter:v0.15.1",
      "sudo mkdir -p /opt/trippop/docker-images",
      "sudo docker save mariadb:10.11 -o /opt/trippop/docker-images/mariadb-10.11.tar",
      "sudo docker save quay.io/prometheus/node-exporter:v1.8.2 -o /opt/trippop/docker-images/node-exporter-v1.8.2.tar",
      "sudo docker save prom/mysqld-exporter:v0.15.1 -o /opt/trippop/docker-images/mysqld-exporter-v0.15.1.tar"
    ]
  }
}
