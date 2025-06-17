# main.tf - Complete VPC Configuration

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
# Using data source to get all Availability Zones in region
data "aws_availability_zones" "available_zones" {}

#######################################################################################################
# Creating VPC
#######################################################################################################
resource "aws_vpc" "bsp_vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "bsp-vpc-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Internet Gateway and attach it to VPC
#######################################################################################################
resource "aws_internet_gateway" "bsp_internet_gateway" {
  vpc_id = aws_vpc.bsp_vpc.id

  tags = merge(
    var.tags,
    {
      Name = "bsp-igw-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Public Subnet AZ1
#######################################################################################################
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.bsp_vpc.id
  cidr_block              = var.public_subnet_az1_cidr
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "bsp-public-subnet-az1-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Public Subnet AZ2
#######################################################################################################
resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.bsp_vpc.id
  cidr_block              = var.public_subnet_az2_cidr
  availability_zone       = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "bsp-public-subnet-az2-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Private Subnet AZ1
#######################################################################################################
resource "aws_subnet" "private_subnet_az1" {
  vpc_id                  = aws_vpc.bsp_vpc.id
  cidr_block              = var.private_subnet_az1_cidr
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "bsp-private-subnet-az1-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Private Subnet AZ2
#######################################################################################################
resource "aws_subnet" "private_subnet_az2" {
  vpc_id                  = aws_vpc.bsp_vpc.id
  cidr_block              = var.private_subnet_az2_cidr
  availability_zone       = data.aws_availability_zones.available_zones.names[1]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "bsp-private-subnet-az2-${var.env}"
    }
  )
}

#######################################################################################################
# Creating EIP for NAT Gateway
#######################################################################################################
resource "aws_eip" "nat_eip" {

  tags = merge(
    var.tags,
    {
      Name = "bsp-nat-eip-${var.env}"
    }
  )
}

#######################################################################################################
# Creating NAT Gateway for Private Subnet AZ1
#######################################################################################################
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = merge(
    var.tags,
    {
      Name = "bsp-nat-gateway-${var.env}"
    }
  )

  depends_on = [aws_internet_gateway.bsp_internet_gateway]
}

#######################################################################################################
# Creating Route Table and add Public Route
#######################################################################################################
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.bsp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bsp_internet_gateway.id
  }

  tags = merge(
    var.tags,
    {
      Name = "bsp-public-route-table-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Route Table and add Private Route for AZ1
#######################################################################################################
resource "aws_route_table" "private_route_table_az1" {
  vpc_id = aws_vpc.bsp_vpc.id

  tags = merge(
    var.tags,
    {
      Name = "bsp-private-route-table-az1-${var.env}"
    }
  )
}

#######################################################################################################
# Creating Route Table and add Private Route for AZ2
#######################################################################################################
resource "aws_route_table" "private_route_table_az2" {
  vpc_id = aws_vpc.bsp_vpc.id

  tags = merge(
    var.tags,
    {
      Name = "bsp-private-route-table-az2-${var.env}"
    }
  )
}

#######################################################################################################
# Adding route to NAT Gateway for private subnet AZ1
#######################################################################################################
resource "aws_route" "private_route_az1" {
  route_table_id         = aws_route_table.private_route_table_az1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

#######################################################################################################
# Adding route to NAT Gateway for private subnet AZ2
#######################################################################################################
resource "aws_route" "private_route_az2" {
  route_table_id         = aws_route_table.private_route_table_az2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

#######################################################################################################
# Associating Public Subnet in AZ1 to route table
#######################################################################################################
resource "aws_route_table_association" "public_subnet_az1_route_table_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

#######################################################################################################
# Associating Public Subnet in AZ2 to route table
#######################################################################################################
resource "aws_route_table_association" "public_subnet_az2_route_table_association" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

#######################################################################################################
# Associating Private Subnet in AZ1 to private route table AZ1
#######################################################################################################
resource "aws_route_table_association" "private_subnet_az1_route_table_association_az1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_route_table_az1.id
}

#######################################################################################################
# Associating Private Subnet in AZ2 to private route table AZ2
#######################################################################################################
resource "aws_route_table_association" "private_subnet_az2_route_table_association_az2" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_route_table_az2.id
}