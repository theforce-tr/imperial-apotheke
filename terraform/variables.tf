locals {
  core_infrastructure_tag = {
    Environment = var.environment
    Owner       = "kaan.oflaz@the-force.org.tr"
    ManagedBy   = "Terraform"
  }
}

variable "aws_region" {
  description = "The AWS region to deploy the resources of the stacks in."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "The AWS SSO profile to use for authentication."
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment to deploy the resources in"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the load balancer"
  type        = string
  default     = "the-force.org.tr"
}

variable "db_name" {
  description = ""
  type        = string
}

variable "db_port" {
  description = ""
  type        = string
}


variable "db_user" {
  description = ""
  type        = string
}

variable "db_password" {
  description = "Database password for Shopware"
  type        = string
}