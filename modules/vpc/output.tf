# outputs.tf

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.bsp_vpc.id
}

# Internet Gateway Outputs
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.bsp_internet_gateway.id
}

# Public Subnet AZ1 Outputs
output "public_subnet_az1_id" {
  description = "ID of the public subnet in AZ1"
  value       = aws_subnet.public_subnet_az1.id
}

# Private Subnet AZ1 Outputs
output "private_subnet_az1_id" {
  description = "ID of the private subnet in AZ1"
  value       = aws_subnet.private_subnet_az1.id
}

# NAT Gateway EIP Outputs
output "nat_eip_id" {
  description = "ID of the Elastic IP for NAT Gateway"
  value       = aws_eip.nat_eip.id
}

# NAT Gateway Outputs
output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.nat_gateway.id
}

# Public Route Table Outputs
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_route_table.id
}

# Private Route Table AZ1 Outputs
output "private_route_table_az1_id" {
  description = "ID of the private route table for AZ1"
  value       = aws_route_table.private_route_table_az1.id
}

# Route Outputs
output "private_route_az1_id" {
  description = "ID of the private route for AZ1"
  value       = aws_route.private_route_az1.id
}

