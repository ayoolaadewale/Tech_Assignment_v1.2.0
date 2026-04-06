terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> >= 0.13.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
    }
    kubernetes = { 
      source = "hashicorp/kubernetes" 
      version = "~> 3.0.1" 
    }
    helm = { 
      source = "hashicorp/helm"
      version = "~> 3.1.1" 
    }
  }
}
provider "aws" {
  region = var.aws_region
}