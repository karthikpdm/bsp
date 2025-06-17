# variables.tf

# variable "vpc_cidr_block" {
#   description = "CIDR block for the VPC"
#   type        = string
  
# }

# variable "public_subnet_az1_cidr" {
#   description = "CIDR block for public subnet in AZ1"
#   type        = string
# }
# variable "public_subnet_az2_cidr" {
#   description = "CIDR block for public subnet in AZ1"
#   type        = string
# }

# variable "private_subnet_az1_cidr" {
#   description = "CIDR block for private subnet in AZ1"
#   type        = string
# }


# variable "private_subnet_az2_cidr" {
#   description = "CIDR block for private subnet in AZ1"
#   type        = string
# }

variable "env" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}



#####################   eks   ############################



variable "eks_version" {
  description = "The version of the EKS cluster"
  type        = string
}



#####################   worker node   ############################

variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "disk_size" {
  description = "EBS volume size in GB"
  type        = number
}


#####################   sg   ############################


variable "master_ingress_rules" {
  description = "List of ingress rules for the EKS master security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}

variable "master_egress_rules" {
  description = "List of egress rules for the EKS master security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}



variable "workers_ingress_rules" {
  description = "List of ingress rules for the EKS workers security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}

variable "workers_egress_rules" {
  description = "List of egress rules for the EKS workers security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}



#####################   istio   ############################


variable "istio_version" {
  description = "The version of the istio"
  type        = string
}

