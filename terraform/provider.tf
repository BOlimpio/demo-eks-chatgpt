terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    helm = {
      source = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
  
  backend "s3" {
    bucket         = "poc-projects-terraform-statefile"
    key            = "chatgpt/terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}
