########################################################
# vpc.tf
########################################################

####################
# Variables
####################
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Map of AZ → CIDR for public subnets"
  type        = map(string)
  default = {
    "eu-central-1a" = "10.0.1.0/24"
    "eu-central-1b" = "10.0.3.0/24"
  }
}

variable "private_subnets" {
  description = "Map of AZ → CIDR for private subnets"
  type        = map(string)
  default = {
    "eu-central-1a" = "10.0.2.0/24"
    "eu-central-1b" = "10.0.4.0/24"
  }
}

####################
# VPC & IGW
####################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "shopware-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "shopware-igw"
  }
}

####################
# Subnets
####################
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "shopware-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "shopware-private-${each.key}"
  }
}

####################
# NAT Gateway
####################
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "shopware-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  # pick the first public subnet for the NAT GW
  subnet_id     = values(aws_subnet.public)[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "shopware-nat"
  }
}

####################
# Route Tables
####################
# Public → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "shopware-public-rt"
  }
}

# Private → NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "shopware-private-rt"
  }
}

####################
# Route Table Associations
####################
resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
