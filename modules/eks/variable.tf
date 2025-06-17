
#####################   eks   ############################


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


variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "disk_size" {
  description = "EBS volume size in GB"
  type        = number
}

variable "worker_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  type        = string
}

#####################   istio   ############################


variable "istio_version" {
  description = "The version of the istio"
  type        = string
}
