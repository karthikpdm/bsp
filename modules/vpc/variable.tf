# variables.tf

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  
}

variable "public_subnet_az1_cidr" {
  description = "CIDR block for public subnet in AZ1"
  type        = string
}

variable "public_subnet_az2_cidr" {
  description = "CIDR block for public subnet in AZ1"
  type        = string
}


variable "private_subnet_az1_cidr" {
  description = "CIDR block for private subnet in AZ1"
  type        = string
}

variable "private_subnet_az2_cidr" {
  description = "CIDR block for private subnet in AZ1"
  type        = string
}

variable "env" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}