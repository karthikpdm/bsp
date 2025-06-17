

variable "env" {
  type        = string
  description = "Environment (e.g., dev, prod)"
  default     = "dev"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
}


########################################################################################################
                # master_ingress_rules
########################################################################################################


variable "master_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "List of ingress rules for EKS master"
  default = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.11.0.0/19"]
      description = "Allow HTTPS from anywhere (for kubectl)"
    }
  ]
}


#######################################################################################################

variable "master_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "List of egress rules for EKS master"
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["10.11.0.0/19"]
      description = "Allow all outbound traffic"
    }
  ]
}

#########################################################################################################
                # worker_rules
########################################################################################################
variable "workers_ingress_rules" {
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    description     = string
  }))
  description = "List of ingress rules for EKS workers"
}

########################################################################################################

variable "workers_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "List of egress rules for EKS workers"
}

