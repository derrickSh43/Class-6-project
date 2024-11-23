// Variables for customization
variable "central_region" {
  description = "The central region where all data will be directed and stored"
  default     = "us-east-1" // Replace with your central region
}

variable "regions" {
  description = "List of regions to deploy Transit Gateways and route data to the central region"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"] // Add all 7 regions here
}

variable "vpc_attachments" {
  description = "Map of VPC attachments per region and environment"
  type        = map(map(string))
  default = {
    "us-east-1" = {
      "dev"      = "vpc-attachment-id-dev",
      "security" = "vpc-attachment-id-security" // VPC for syslog storage
    }
    "us-west-2" = {
      "test" = "vpc-attachment-id-test",
      "prod" = "vpc-attachment-id-prod"
    }
    // Add remaining regions and VPC mappings
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

// Provider block for deployment in multiple regions
provider "aws" {
  alias  = each.key
  region = each.key
}

// Create a Transit Gateway in each region
resource "aws_ec2_transit_gateway" "tgw" {
  for_each    = toset(var.regions)
  description = "Transit Gateway for ${each.key}"

  tags = merge(var.tags, {
    Name = "TGW-${each.key}"
  })
}

// Create a Route Table for each Transit Gateway
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  for_each = aws_ec2_transit_gateway.tgw

  transit_gateway_id = each.value.id

  tags = merge(var.tags, {
    Name = "TGW-Route-Table-${each.key}"
  })
}

// Route propagation for VPC attachments
resource "aws_ec2_transit_gateway_route_table_propagation" "route_propagation" {
  for_each = flatten([
    for region, vpcs in var.vpc_attachments : [
      for vpc, attachment_id in vpcs : {
        region         = region
        vpc_name       = vpc
        attachment_id  = attachment_id
        route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[region].id
      }
    ]
  ])

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id

  tags = merge(var.tags, {
    Name = "Propagation-${each.value.region}-${each.value.vpc_name}"
  })
}

// Route data to the central region from all other regions
resource "aws_ec2_transit_gateway_route" "central_region_routing" {
  for_each = flatten([
    for region, vpcs in var.vpc_attachments : [
      for vpc, attachment_id in vpcs : {
        region         = region
        vpc_name       = vpc
        attachment_id  = attachment_id
        is_central     = region == var.central_region
        route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[region].id
      }
    ]
  ])

  // Only set a route for non-central regions
  count = each.value.is_central ? 0 : 1

  transit_gateway_route_table_id = each.value.route_table_id
  destination_cidr_block         = "10.230.0.0/16" // Replace with the CIDR block of the security zone in the central region
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.security_attachment.id

  tags = merge(var.tags, {
    Name = "Route-to-Central-${each.value.region}-${each.value.vpc_name}"
  })
}

// Block outbound data flow from the central region
resource "aws_ec2_transit_gateway_route" "block_outbound_from_central" {
  for_each = aws_ec2_transit_gateway.tgw

  count = each.key == var.central_region ? 1 : 0

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[each.key].id
  destination_cidr_block         = "0.0.0.0/0"

  blackhole = true

  tags = merge(var.tags, {
    Name = "Block-Outbound-From-Central"
  })
}
