terraform {
  required_version = ">= 1.0.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "= 2.2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.6"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}


variable "region" {
  type        = string
  description = "AWS region to deploy the resources"
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}

provider "opensearch" {
  url         = module.oss_collections["ai-gsp-kb-oss-dev"].endpoint
  healthcheck = false
}
