data "aws_availability_zones" "available" {
  state = "available"
}

# Create the VPC
resource "aws_vpc" "osdu-ir-vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "osdu-vpc"
  }
}

# Create 2 public subnets
resource "aws_subnet" "osdu-ir-public" {
  count                   = 2
  vpc_id                  = aws_vpc.osdu-ir-vpc.id
  cidr_block              = element(["10.13.0.0/20", "10.13.16.0/20"], count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "osdu-ir-public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

# Create 2 private subnets
resource "aws_subnet" "osdu-ir-private" {
  count             = 2
  vpc_id            = aws_vpc.osdu-ir-vpc.id
  cidr_block        = element(["10.13.128.0/20", "10.13.144.0/20"], count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "osdu-ir-private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

# Create the Internet gateway
resource "aws_internet_gateway" "osdu-ir-igw" {
  vpc_id = aws_vpc.osdu-ir-vpc.id
  tags = {
    Name = "osdu-ir-igw"
  }
}

# Elastic IP's for NAT Gateway
resource "aws_eip" "osdu-ir-nat-eip" {
  count  = 2
  domain = "vpc"
  tags = {
    Name = "osdu-ir-nat-eip-${count.index + 1}"
  }
}

# Create **NAT Gateways** for private subnets to access internet
resource "aws_nat_gateway" "osdu-ir-nat-gateway" {
  count         = 2
  allocation_id = aws_eip.osdu-ir-nat-eip[count.index].id
  subnet_id     = aws_subnet.osdu-ir-public[count.index].id
  tags = {
    Name = "osdu-ir-nat-gateway-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.osdu-ir-igw]
}

# Public route table
resource "aws_route_table" "osdu-ir-public-route-table" {
  vpc_id = aws_vpc.osdu-ir-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.osdu-ir-igw.id
  }
  tags = {
    Name = "osdu-ir-public-route-table"
  }
}

# Associate Public Subnet
resource "aws_route_table_association" "osdu-ir-public-route-association" {
  count          = 2
  subnet_id      = aws_subnet.osdu-ir-public[count.index].id
  route_table_id = aws_route_table.osdu-ir-public-route-table.id
}

# Private route table
resource "aws_route_table" "osdu-ir-private-route-table" {
  count  = 2
  vpc_id = aws_vpc.osdu-ir-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.osdu-ir-nat-gateway[count.index].id
  }
  tags = {
    Name = "osdu-ir-private-route-table-${count.index + 1}"
  }
}

# Association for Private Route
resource "aws_route_table_association" "osdu-ir-private-route-association" {
  count          = 2
  subnet_id      = aws_subnet.osdu-ir-private[count.index].id
  route_table_id = aws_route_table.osdu-ir-private-route-table[count.index].id
}
