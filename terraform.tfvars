################################################################################
##############################  vpc #############################################
################################################################################

# vpc_cidr_block = "10.0.0.0/16"

# # Subnet Configuration 


# # Public Subnet Configuration - /24 gives 251 usable IPs each
# public_subnet_az1_cidr = "10.0.1.0/24"
# public_subnet_az2_cidr = "10.0.2.0/24"

# # Private Subnet Configuration - /24 gives 251 usable IPs each
# private_subnet_az1_cidr = "10.0.11.0/24"
# private_subnet_az2_cidr = "10.0.12.0/24"


# Environment
env = "poc"

# Tags
tags = {
  Project     = "BSP"
  Environment = "poc"
  Owner       = "Kartrhikbm"
  Terraform   = "true"
}


################################################################################
##############################  eks #############################################
################################################################################


eks_version      = "1.32" 
instance_type    = "m5.2xlarge"
disk_size        = 20
region           = "us-east-1"



##############################  istio #############################################


# istio_version =  "1.17.2"
istio_version =  "1.20.2"




################################################################################
##############################  sg #############################################
################################################################################

# Security Group Rules
master_ingress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming HTTPS traffic from anywhere"
  }
]

master_egress_rules = [
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outgoing traffic"
  }
]

workers_ingress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS incoming traffic from anywhere"
  },
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"  
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP incoming traffic from anywhere"
  }
]

workers_egress_rules = [
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outgoing traffic"
  }
]








