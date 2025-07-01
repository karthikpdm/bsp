variable "region" {
  type        = string
  description = "Region"
  default     = "us-east-1"
}

variable "cidr_block" {
  type        = string
  description = "VPC Cidr block address"
  default     = "10.13.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "The EKS cluster name"
  default     = "osdu-ir-eks-cluster"
}

variable "csi_ebs_driver_version" {
  type        = string
  description = "EBS CSI Driver version"
  default     = "v1.35.0-eksbuild.1"
}

variable "eks_version" {
  type        = string
  description = "EKS version"
  default     = "1.31"
}

variable "instance_type" {
  type        = string
  description = "The worker node EC2 compute power"
  default     = "m5.2xlarge"
}

# This is not used currently. We are using the ASW provided Linux OS
variable "ami_id" {
  type        = string
  description = "We are using the Ubuntu V22.04"
  default     = "ami-0f9de6e2d2f067fca"
}

variable "key_pair_name" {
  type        = string
  description = "The key pair will be required to access the workernodes"
  #default     = "osdu-ir-worker-node-key-pair"
  default = "ir-test"
}






##############################################################################

# =========================================
# OSDU Monitoring Infrastructure Terraform
# AWS CloudWatch + Amazon Managed Grafana + Amazon Managed Prometheus
# Integrates with existing osdu-ir-eks-cluster
# =========================================

# ----------------------------------------
# Variables (add these to your existing variables.tf)
# ----------------------------------------
# variable "grafana_admin_email" {
#   description = "Admin email for Grafana workspace and alert notifications"
#   type        = string
#   default     = "karthik.bm@trianz.com"
# }


# variable "enable_cloudwatch_insights" {
#   description = "Enable CloudWatch Container Insights"
#   type        = bool
#   default     = true
# }

# variable "prometheus_retention_days" {
#   description = "Prometheus data retention in days"
#   type        = number
#   default     = 150
# }

# variable "monitoring_tags" {
#   description = "Additional tags for monitoring resources"
#   type        = map(string)
#   default = {
#     Component = "monitoring"
#     ManagedBy = "terraform"
#   }
# }

