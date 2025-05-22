terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.97.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.aws_region
  # Use profile only if defined and not running in CI
  profile = can(var.aws_profile) && var.aws_profile != "" ? var.aws_profile : null
}