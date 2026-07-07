terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # S3 버킷 이름 난수 생성을 위한 random 프로바이더 추가
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}