#######################################
# Variables
#######################################

variable "regions" {
  description = "List of regions to deploy the VPC"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-central-1"] // Add all regions here
}

variable "base_cidr_block" {
  description = "Base CIDR block for the first region"
  default     = "10.231.0.0/16" // Starting CIDR block
}

#######################################
# Local Values
#######################################

// Dynamically calculate non-overlapping CIDR blocks for each region
locals {
  cidr_blocks = [for index, region in var.regions : cidrsubnet(var.base_cidr_block, 8, index)]
}

#######################################
# AWS Provider
#######################################

provider "aws" {
  alias  = each.key
  region = each.key
}

#######################################
# Code
#######################################
// 1.  Create Subnets (Public and Private)
resource "aws_subnet" "public_subnet" {
  for_each            = toset(var.regions)
  count               = 2 // Assuming two subnets per region (adjust if necessary)
  vpc_id              = aws_vpc.vpc[each.key].id
  cidr_block          = cidrsubnet(local.cidr_blocks[values(toset(var.regions))[count.index]], 8, count.index + 1)
  availability_zone   = "${each.key}${["a", "b"][count.index]}"

  tags = {
    Name = "${each.key} Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each            = toset(var.regions)
  count               = 2 // Assuming two subnets per region (adjust if necessary)
  vpc_id              = aws_vpc.vpc[each.key].id
  cidr_block          = cidrsubnet(local.cidr_blocks[values(toset(var.regions))[count.index]], 8, count.index + 11)
  availability_zone   = "${each.key}${["a", "b"][count.index]}"

  tags = {
    Name = "${each.key} Private Subnet ${count.index + 1}"
  }
}


// 2. Internet Gateway and Route Tables
resource "aws_internet_gateway" "igw" {
  for_each = toset(var.regions)
  vpc_id   = aws_vpc.vpc[each.key].id

  tags = {
    Name = "${each.key} Internet Gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  for_each = toset(var.regions)
  vpc_id   = aws_vpc.vpc[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[each.key].id
  }

  tags = {
    Name = "${each.key} Public Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  for_each = toset(var.regions)
  count    = 2 // Assuming two subnets per region (adjust if necessary)
  route_table_id = aws_route_table.public_route_table[each.key].id
  subnet_id      = aws_subnet.public_subnet[each.key].id
}