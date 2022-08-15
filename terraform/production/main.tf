terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
    }
  }

  # Requires S3 bucket & Dynamo DB to be configured, please see README.md
  backend "s3" {
    bucket         = "datamart-terraform-state"
    encrypt        = true
    dynamodb_table = "tfstate-locks"
    key            = "datamart-production"
    region         = "eu-west-2"
  }

  required_version = "~> 1.0.0"
}

provider "aws" {
  region = "eu-west-1"
}

module "networking" {
  source = "../modules/networking"
}