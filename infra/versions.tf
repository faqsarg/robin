terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "robin-challenge"

    workspaces {
      name = "robin-infra"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
