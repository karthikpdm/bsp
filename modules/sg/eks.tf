
# Data sources for existing VPC components
data "aws_vpc" "bsp_vpc" {
  filter {
    name   = "tag:Name"
    values = ["bsp-vpc-${var.env}"]
  }
}


# Security Group for EKS Master (Control Plane)
resource "aws_security_group" "eks_master_sg" {
  name        = "bsp-eks-master-sg-${var.env}"
  description = "Security group for EKS control plane"
  vpc_id      = data.aws_vpc.bsp_vpc.id
  

   tags = merge(
    var.tags,
    {
      Name = "bsp-eks-master-sg-${var.env}"
    }
  )

  dynamic "ingress" {
    for_each = var.master_ingress_rules
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      description      = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = var.master_egress_rules
    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      description      = egress.value.description
    }
  }
}