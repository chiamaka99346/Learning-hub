terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 5.60" }
    tls  = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
  # backend "s3" {
  #   bucket         = "YOUR_TFSTATE_BUCKET"
  #   key            = "jenkins/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "YOUR_TF_LOCK_TABLE"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}