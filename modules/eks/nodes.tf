
#########################################################################
# SHARED RESOURCES - AMI AND BASE CONFIGURATIONS
#########################################################################

# Ubuntu 22.04 EKS-optimized AMI (shared across all node groups)
data "aws_ami" "eks-worker-ami" {
  filter {
    name   = "name"
    values = ["ubuntu-eks/k8s_${var.eks_version}/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical's Account ID for Ubuntu AMIs
}

#########################################################################
# NODE GROUP 1: ISTIO + KEYCLOAK NODES
# Purpose: Service mesh, ingress gateway, and authentication
#########################################################################

# Launch Template for Istio Nodes
resource "aws_launch_template" "eks-istio-node" {
  name = "bsp-eks-istio-nodes-${var.env}"

  # Security configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"  # Enable for better service discovery
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

  # Instance configuration - Lighter for Istio components
  image_id      = data.aws_ami.eks-worker-ami.id
  instance_type = var.istio_instance_type  # e.g., "t3.large"

  # Istio-optimized user data
  user_data = base64encode(local.istio-node-userdata)
  
  # Storage configuration - Moderate storage for Istio
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.istio_disk_size  # e.g., 80GB
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
    }
  }

  # Tags for launch template
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-istio-launch-template-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Istio-ServiceMesh"
    }
  )
  
  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-istio-node-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Istio-ServiceMesh"
        "node-role" = "osdu-istio-keycloak"
      }
    )
  }
  
  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-istio-node-volume-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Istio-ServiceMesh"
      }
    )
  }
}

# Istio Node Group
resource "aws_eks_node_group" "istio-node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "bsp-eks-istio-node-${var.env}"
  node_role_arn   = var.worker_role_arn
  subnet_ids      = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]

  # Scaling for Istio components (HA setup)
  scaling_config {
    desired_size = var.istio_node_config.desired_size  # Default: 2
    max_size     = var.istio_node_config.max_size      # Default: 4
    min_size     = var.istio_node_config.min_size      # Default: 1
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
    version = aws_launch_template.eks-istio-node.latest_version
    name    = aws_launch_template.eks-istio-node.name
  }

  # Node labels for pod scheduling
  labels = {
    "node-role"           = "osdu-istio-keycloak"
    "workload-type"       = "istio"
    "component"           = "service-mesh"
    "istio-injection"     = "enabled"
  }

  # Taints to ensure only Istio/Keycloak pods run here
  taint {
    key    = "node-role"
    value  = "osdu-istio-keycloak"
    effect = "NO_SCHEDULE"
  }

  # Enhanced tags
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-istio-nodegroup-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Istio-ServiceMesh"
      "kubernetes.io/cluster/${aws_eks_cluster.eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.eks.name}" = "owned"
    }
  )
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Ensure proper creation order
  depends_on = [aws_eks_cluster.eks]
}

#########################################################################
# NODE GROUP 2: BACKEND DATABASE NODES
# Purpose: MinIO, PostgreSQL, Elasticsearch, RabbitMQ
#########################################################################

# Launch Template for Backend Nodes
resource "aws_launch_template" "eks-backend-node" {
  name = "bsp-eks-backend-nodes-${var.env}"

  # Security configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
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

  # Instance configuration - Larger for database workloads
  image_id      = data.aws_ami.eks-worker-ami.id
  instance_type = var.backend_instance_type  # e.g., "m5.2xlarge"

  # Backend-optimized user data
  user_data = base64encode(local.backend-node-userdata)
  
  # Storage configuration - High storage for databases
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.backend_disk_size  # e.g., 200GB
      volume_type           = "gp3"
      iops                  = 4000  # Higher IOPS for databases
      throughput            = 250   # Higher throughput
    }
  }

  # Additional storage for database data
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.backend_data_disk_size  # e.g., 500GB
      volume_type           = "gp3"
      iops                  = 4000
      throughput            = 250
    }
  }

  # Tags for launch template
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-backend-launch-template-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Backend-Databases"
    }
  )
  
  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-backend-node-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Backend-Databases"
        "node-role" = "osdu-backend"
      }
    )
  }
  
  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-backend-node-volume-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Backend-Databases"
      }
    )
  }
}

# Backend Node Group
resource "aws_eks_node_group" "backend-node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "bsp-eks-backend-node-${var.env}"
  node_role_arn   = var.worker_role_arn
  subnet_ids      = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]

  # Scaling for database workloads
  scaling_config {
    desired_size = var.backend_node_config.desired_size  # Default: 3
    max_size     = var.backend_node_config.max_size      # Default: 5
    min_size     = var.backend_node_config.min_size      # Default: 2
  }

  # Update configuration - Conservative for databases
  update_config {
    max_unavailable = 1
  }
  
  # Custom AMI and launch template for Ubuntu
  ami_type              = "CUSTOM"
  capacity_type         = "ON_DEMAND"
  force_update_version  = true
  
  launch_template {
    version = aws_launch_template.eks-backend-node.latest_version
    name    = aws_launch_template.eks-backend-node.name
  }

  # Node labels for backend scheduling
  labels = {
    "node-role"           = "osdu-backend"
    "workload-type"       = "database"
    "component"           = "backend-services"
    "storage-optimized"   = "true"
  }

  # Taints for backend workloads
  taint {
    key    = "node-role"
    value  = "osdu-backend"
    effect = "NO_SCHEDULE"
  }

  # Enhanced tags
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-backend-nodegroup-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Backend-Databases"
      "kubernetes.io/cluster/${aws_eks_cluster.eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.eks.name}" = "owned"
    }
  )
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Ensure proper creation order
  depends_on = [aws_eks_cluster.eks]
}

#########################################################################
# NODE GROUP 3: FRONTEND OSDU MICROSERVICES NODES
# Purpose: OSDU APIs, Airflow, Redis
#########################################################################

# Launch Template for Frontend Nodes
resource "aws_launch_template" "eks-frontend-node" {
  name = "bsp-eks-frontend-nodes-${var.env}"

  # Security configuration
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
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

  # Instance configuration - Balanced for microservices
  image_id      = data.aws_ami.eks-worker-ami.id
  instance_type = var.frontend_instance_type  # e.g., "m5.xlarge"

  # Frontend-optimized user data
  user_data = base64encode(local.frontend-node-userdata)
  
  # Storage configuration - Moderate storage for APIs
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.frontend_disk_size  # e.g., 150GB
      volume_type           = "gp3"
      iops                  = 3500
      throughput            = 200
    }
  }

  # Tags for launch template
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-frontend-launch-template-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Frontend-Microservices"
    }
  )
  
  # Tag specifications for instances
  tag_specifications {
    resource_type = "instance"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-frontend-node-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Frontend-Microservices"
        "node-role" = "osdu-frontend"
      }
    )
  }
  
  # Tag specifications for volumes
  tag_specifications {
    resource_type = "volume"
    
    tags = merge(
      var.tags,
      {
        Name = "bsp-eks-frontend-node-volume-${var.env}"
        OS   = "Ubuntu-22.04"
        Component = "Frontend-Microservices"
      }
    )
  }
}

# Frontend Node Group
resource "aws_eks_node_group" "frontend-node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "bsp-eks-frontend-node-${var.env}"
  node_role_arn   = var.worker_role_arn
  subnet_ids      = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]

  # Scaling for OSDU microservices
  scaling_config {
    desired_size = var.frontend_node_config.desired_size  # Default: 4
    max_size     = var.frontend_node_config.max_size      # Default: 8
    min_size     = var.frontend_node_config.min_size      # Default: 2
  }

  # Update configuration
  update_config {
    max_unavailable_percentage = 25  # More aggressive for stateless services
  }
  
  # Custom AMI and launch template for Ubuntu
  ami_type              = "CUSTOM"
  capacity_type         = "ON_DEMAND"
  force_update_version  = true
  
  launch_template {
    version = aws_launch_template.eks-frontend-node.latest_version
    name    = aws_launch_template.eks-frontend-node.name
  }

  # Node labels for frontend scheduling
  labels = {
    "node-role"           = "osdu-frontend"
    "workload-type"       = "microservices"
    "component"           = "osdu-apis"
    "compute-optimized"   = "true"
  }

  # Taints for frontend workloads
  taint {
    key    = "node-role"
    value  = "osdu-frontend"
    effect = "NO_SCHEDULE"
  }

  # Enhanced tags
  tags = merge(
    var.tags,
    {
      Name = "bsp-eks-frontend-nodegroup-${var.env}"
      OS   = "Ubuntu-22.04"
      Component = "Frontend-Microservices"
      "kubernetes.io/cluster/${aws_eks_cluster.eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.eks.name}" = "owned"
    }
  )
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Ensure proper creation order
  depends_on = [aws_eks_cluster.eks]
}



########################################################################################################################################################



#########################################################################
# USER DATA CONFIGURATIONS
#########################################################################

# Base user data for all nodes
locals {
  base-node-userdata = <<-EOT
#!/bin/bash
set -o xtrace

# EKS bootstrap
/etc/eks/bootstrap.sh ${aws_eks_cluster.eks.name} \
  --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority[0].data}' \
  --api-server-endpoint '${aws_eks_cluster.eks.endpoint}' \
  --container-runtime containerd

# System optimizations for OSDU
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'fs.file-max=65536' >> /etc/sysctl.conf
echo 'net.core.somaxconn=32768' >> /etc/sysctl.conf
sysctl -p

# Increase inotify limits
echo 'fs.inotify.max_user_watches=524288' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances=512' >> /etc/sysctl.conf
sysctl -p
EOT

  # Istio-specific user data
  istio-node-userdata = <<-EOT
${local.base-node-userdata}

# Istio-specific optimizations
echo 'net.ipv4.tcp_max_syn_backlog=16384' >> /etc/sysctl.conf
echo 'net.core.netdev_max_backlog=16384' >> /etc/sysctl.conf
sysctl -p

# Configure node labels
kubectl label node $(hostname -f) node-role=osdu-istio-keycloak --overwrite || true
EOT

  # Backend-specific user data
  backend-node-userdata = <<-EOT
${local.base-node-userdata}

# Database-specific optimizations
echo 'vm.swappiness=1' >> /etc/sysctl.conf
echo 'vm.dirty_ratio=15' >> /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' >> /etc/sysctl.conf
sysctl -p

# Configure additional disk for database storage
if [ -b /dev/nvme2n1 ] || [ -b /dev/xvdf ]; then
  DEVICE=$(lsblk -f | grep -E "(nvme2n1|xvdf)" | head -1 | awk '{print "/dev/"$1}')
  if [ ! -z "$DEVICE" ]; then
    mkfs.ext4 $DEVICE
    mkdir -p /var/lib/database-storage
    mount $DEVICE /var/lib/database-storage
    echo "$DEVICE /var/lib/database-storage ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
fi

# Configure node labels
kubectl label node $(hostname -f) node-role=osdu-backend --overwrite || true
EOT

  # Frontend-specific user data
  frontend-node-userdata = <<-EOT
${local.base-node-userdata}

# Microservices-specific optimizations
echo 'net.ipv4.ip_local_port_range=1024 65535' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_tw_reuse=1' >> /etc/sysctl.conf
sysctl -p

# Configure log rotation for high-volume logs
cat > /etc/logrotate.d/containers << 'EOF'
/var/log/pods/*/*.log {
    daily
    copytruncate
    rotate 7
    delaycompress
    missingok
    notifempty
    maxsize 100M
}
EOF

# Configure node labels
kubectl label node $(hostname -f) node-role=osdu-frontend --overwrite || true
EOT
}




# # EKS Node Group - Ubuntu 22.04 with Custom Configuration
# resource "aws_eks_node_group" "node-grp" {
#   cluster_name    = aws_eks_cluster.eks.name
#   node_group_name = "bsp-eks-node-${var.env}"
#   node_role_arn   = var.worker_role_arn
#   subnet_ids      = [data.aws_subnet.private_subnet_az1.id, data.aws_subnet.private_subnet_az2.id]

#   # Fixed 3 nodes - no auto-scaling
#   scaling_config {
#     desired_size = 5
#     max_size     = 5
#     min_size     = 4
#   }

#   # Update configuration
#   update_config {
#     max_unavailable = 1
#   }
  
#   # Custom AMI and launch template for Ubuntu
#   ami_type              = "CUSTOM"
#   capacity_type         = "ON_DEMAND"
#   force_update_version  = true
  
#   launch_template {
#     version = aws_launch_template.eks-node.latest_version
#     name    = aws_launch_template.eks-node.name
#   }

#   # Enhanced tags
#   tags = merge(
#     var.tags,
#     {
#       Name = "bsp-eks-nodegroup-${var.env}"
#       OS   = "Ubuntu-22.04"
#     }
#   )
  
#   # Lifecycle management
#   lifecycle {
#     create_before_destroy = true
#   }

#   # Ensure proper creation order
#   depends_on = [aws_eks_cluster.eks]
# }

# # Ubuntu 22.04 EKS-optimized AMI
# data "aws_ami" "eks-worker-ami" {
#   filter {
#     name   = "name"
#     values = ["ubuntu-eks/k8s_${var.eks_version}/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }

#   most_recent = true
#   owners      = ["099720109477"] # Canonical's Account ID for Ubuntu AMIs
# }

# # Launch Template for Ubuntu Nodes
# resource "aws_launch_template" "eks-node" {
#   name = "bsp-eks-nodes-${var.env}"

#   # Security configuration
#   metadata_options {
#     http_endpoint               = "enabled"
#     http_tokens                 = "required"
#     http_put_response_hop_limit = 2
#     instance_metadata_tags      = "disabled"
#   }

#   # Network configuration
#   network_interfaces {
#     associate_public_ip_address = false
#     delete_on_termination       = true
#   }

#   # Monitoring
#   monitoring {
#     enabled = true
#   }

#   # Instance configuration
#   image_id      = data.aws_ami.eks-worker-ami.id
#   instance_type = var.instance_type

#   # Ubuntu user data
#   user_data = base64encode(local.node-userdata)
  
#   # Storage configuration for Ubuntu (uses /dev/sda1)
#   block_device_mappings {
#     device_name = "/dev/sda1" # Ubuntu root device
#     ebs {
#       delete_on_termination = true
#       encrypted             = true
#       volume_size           = var.disk_size
#       volume_type           = "gp3"
#       iops                  = 3000
#       throughput            = 125
#     }
#   }

#   # Tags for launch template
#   tags = merge(
#     var.tags,
#     {
#       Name = "bsp-eks-launch-template-${var.env}"
#       OS   = "Ubuntu-22.04"
#     }
#   )
  
#   # Tag specifications for instances
#   tag_specifications {
#     resource_type = "instance"
    
#     tags = merge(
#       var.tags,
#       {
#         Name = "bsp-eks-node-${var.env}"
#         OS   = "Ubuntu-22.04"
#       }
#     )
#   }
  
#   # Tag specifications for volumes
#   tag_specifications {
#     resource_type = "volume"
    
#     tags = merge(
#       var.tags,
#       {
#         Name = "bsp-eks-node-volume-${var.env}"
#         OS   = "Ubuntu-22.04"
#       }
#     )
#   }
# }
