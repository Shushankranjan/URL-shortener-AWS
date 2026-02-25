# main.tf
# Responsibilities:
#   1. Lock down the Terraform + AWS provider versions
#   2. Point Terraform at your S3 backend for state storage
#   3. Configure the AWS provider with default tags

terraform {
  required_version = ">= 1.6.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40" # 5.40 or any 5.x above — no breaking major jumps
    }
  }

  # S3 Backend: your state file lives here instead of on your laptop
  # IMPORTANT: backend blocks cannot reference variables — values must be hardcoded
  backend "s3" {
    bucket         = "tf-state-url-shortener-200670543092" # your actual bucket
    key            = "url-shortener/terraform.tfstate"     # path inside the bucket
    region         = "us-east-1"
    dynamodb_table = "tf-state-lock-url-shortener"         # prevents concurrent applies
  }
}

provider "aws" {
  region = var.aws_region

  # These tags are automatically applied to EVERY resource Terraform creates.
  # Makes it easy to find all resources in the console + track costs by project.
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "learning"
    }
  }
}
