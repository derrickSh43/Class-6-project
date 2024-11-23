// Variables for customization
variable "region" {
  description = "AWS region to deploy the VPC"
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.230.0.0/16"
}

// Provider configuration
provider "aws" {
  region = var.region
}

// 1. Create the VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.region} Dev VPC"
  }
}

// 2. Create public, private, and backend subnets
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  count             = length(var.availability_zones)
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 1)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.region} Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  count             = length(var.availability_zones)
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 11)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.region} Private Subnet ${count.index + 1}"
  }
}

/*
resource "aws_subnet" "backend_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  count             = length(var.availability_zones)
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 21)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.region} Backend Subnet ${count.index + 1}"
  }
}
*/

// 3. Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "${var.region} Internet Gateway"
  }
}

// 4. Create a Route Table for the public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.region} Public Route Table"
  }
}

// 5. Associate the public subnets with the Route Table
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.availability_zones)
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
}




#######################################
# Variables
#######################################

variable "regions" {
  description = "List of regions to deploy the VPC"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

module "multi_region_vpc" {
  for_each = toset(var.regions)

  source              = "./vpc_module"
  region              = each.key
  cidr_block          = "10.230.0.0/16"
  availability_zones  = ["${each.key}a", "${each.key}b"]
}
