# backend.tf 또는 providers.tf 내부
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 원격 백엔드 설정 (S3 + DynamoDB State Locking)
  backend "s3" {
    bucket         = "my-terraform-state-bucket-2026-giil" # 실제 사용할 고유 S3 버킷 이름
    key            = "vpc/terraform.tfstate"               # S3 내에서 저장될 경로
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock" # 동시성 제어용 DynamoDB 테이블
    encrypt        = true
  }
}