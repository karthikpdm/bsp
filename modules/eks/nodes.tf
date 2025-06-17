# EKS Node Group - Ubuntu 22.04 with Custom Configuration
resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "bsp-eks-node-${var.env}"
  node_role_arn   = var.worker_role_arn
  subnet_ids      = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]

  # Fixed 3 nodes - no auto-scaling
  scaling_config {
    desired_size = 6
    max_size     = 8
    min_size     = 3
  }

  # Update configuration
  update_config {
    max_unavailable = 1
  }
  
  # Custom AMI and launch template for Ubuntu
  ami_type              = "CUSTOM"
  capacity_type         = "ON_DEMAND"
  force_update_version  = true
  
  launch_template {
    version = aws_launch_template.eks-node.latest_version
    name    = aws_launch_template.eks-node.name
  }

  # Enhanced tags
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-nodegroup-${var.env}"
      OS   = "Ubuntu-22.04"
    }
  )
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Ensure proper creation order
  depends_on = [aws_eks_cluster.eks]
}

# Ubuntu 22.04 EKS-optimized AMI
data "aws_ami" "eks-worker-ami" {
  filter {
    name   = "name"
    values = ["ubuntu-eks/k8s_${var.eks_version}/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical's Account ID for Ubuntu AMIs
}

# Launch Template for Ubuntu Nodes
resource "aws_launch_template" "eks-node" {
  name = "bsp-eks-nodes-${var.env}"

  # Security configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  # Network configuration
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  # Instance configuration
  image_id      = data.aws_ami.eks-worker-ami.id
  instance_type = var.instance_type

  # Ubuntu user data
  user_data = base64encode(local.node-userdata)
  
  # Storage configuration for Ubuntu (uses /dev/sda1)
  block_device_mappings {
    device_name = "/dev/sda1" # Ubuntu root device
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
    }
  }

  # Tags for launch template
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-launch-template-${var.env}"
      OS   = "Ubuntu-22.04"
    }
  )
  
  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-node-${var.env}"
        OS   = "Ubuntu-22.04"
      }
    )
  }
  
  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-node-volume-${var.env}"
        OS   = "Ubuntu-22.04"
      }
    )
  }
}
