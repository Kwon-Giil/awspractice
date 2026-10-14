terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 및 DynamoDB 원격 백엔드 설정
  backend "s3" {
    bucket         = "my-terraform-state-bucket-2026-giil" # 사용 중인 버킷 이름
    key            = "vpc/terraform.tfstate"
    region         = "ap-northeast-2" # 현재 사용 중인 리전 (서울)
    dynamodb_table = "terraform-lock" # 앞으로 사용할 DB
  }
}

provider "aws" {
  region = "ap-northeast-2"
}