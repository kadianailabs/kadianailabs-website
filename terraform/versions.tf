terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }

  # ── Remote state (recommended). Create the bucket + DynamoDB table once,
  #    then uncomment. Left commented so `terraform init` works out of the box. ──
  # backend "s3" {
  #   bucket         = "kadianai-terraform-state"
  #   key            = "kadianai-website/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "kadianai-terraform-locks"
  #   encrypt        = true
  # }
}
