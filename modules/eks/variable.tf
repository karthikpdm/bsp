
#####################   eks   ############################

variable "region" {
  description = "region"
  type        = string
}

variable "env" {
  description = "The environment for the infrastructure (e.g., dev, qa, prod)"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}

variable "master_role_arn" {
  description = "The ARN of the IAM role for the EKS master"
  type        = string
}

variable "eks_version" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "eks_master_sg_id" {
  description = "The security group ID for the EKS master"
  type        = string
}




#####################   worker node   ############################


# variable "instance_type" {
#   description = "EC2 instance type for worker nodes"
#   type        = string
# }

# variable "disk_size" {
#   description = "EBS volume size in GB"
#   type        = number
# }

variable "worker_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  type        = string
}


#########################################################################
# REQUIRED VARIABLES
#########################################################################
# Add these to your variables.tf file:

# Instance types for different node groups
# variable "istio_instance_type" {
variable "instance_type" {

  description = "Instance type for Istio nodes"
  type        = string
  default     = "m5.2xlarge"
}

# variable "backend_instance_type" {
#   description = "Instance type for backend database nodes"
#   type        = string
#   default     = "m5.2xlarge"
#   # default     = "t3.large"
# }

# variable "frontend_instance_type" {
#   description = "Instance type for frontend microservice nodes"
#   type        = string
#   default     = "m5.2xlarge"
#   # default     = "t3.large"
# }

# Disk sizes for different node groups
variable "istio_disk_size" {
  description = "Root disk size for Istio nodes in GB"
  type        = number
  default     = 80
}

variable "backend_disk_size" {
  description = "Root disk size for backend nodes in GB"
  type        = number
  default     = 80
}

variable "backend_data_disk_size" {
  description = "Additional data disk size for backend nodes in GB"
  type        = number
  default     = 20
}

variable "frontend_disk_size" {
  description = "Root disk size for frontend nodes in GB"
  type        = number
  default     = 80
}

# Node group scaling configurations
variable "istio_node_config" {
  description = "Scaling configuration for Istio node group"
  type = object({
    desired_size = number
    max_size     = number
    min_size     = number
  })
  default = {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
}

variable "backend_node_config" {
  description = "Scaling configuration for backend node group"
  type = object({
    desired_size = number
    max_size     = number
    min_size     = number
  })
  default = {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
}

variable "frontend_node_config" {
  description = "Scaling configuration for frontend node group"
  type = object({
    desired_size = number
    max_size     = number
    min_size     = number
  })
  default = {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
}

#####################   istio   ############################


variable "istio_version" {
  description = "The version of the istio"
  type        = string
}




# Variables
variable "custom_values_file_path" {
  description = "Path to the custom-values.yaml file"
  type        = string
  default     = "./custom-values.yaml"
}
